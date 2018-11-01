# --
# Modified version of the work: Copyright (C) 2006-2018 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2018 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::Modules::AgentTicketEmailOutbound;

use strict;
use warnings;

use Kernel::System::VariableCheck qw(:all);
use Kernel::Language qw(Translatable);
use Mail::Address;

our $ObjectManagerDisabled = 1;

sub new {
    my ( $Type, %Param ) = @_;

    # allocate new hash for object
    my $Self = {%Param};
    bless( $Self, $Type );

    $Self->{Debug} = $Param{Debug} || 0;

    return $Self;
}

sub Run {
    my ( $Self, %Param ) = @_;

    my $Output;

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ACL restrictions
    $TicketObject->TicketAcl(
        Data          => '-',
        TicketID      => $Self->{TicketID},
        ReturnType    => 'Action',
        ReturnSubType => '-',
        UserID        => $Self->{UserID},
    );
    my %AclAction = $TicketObject->TicketAclActionData();

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # KIX4OTRS-capeIT
    my $ConfigObject  = $Kernel::OM->Get('Kernel::Config');
    my $UserObject    = $Kernel::OM->Get('Kernel::System::User');
    my $ParamObject   = $Kernel::OM->Get('Kernel::System::Web::Request');
    my $SessionObject = $Kernel::OM->Get('Kernel::System::AuthSession');
    my %Preferences   = $UserObject->GetPreferences( UserID => $Self->{UserID} );

    # EO KIX4OTRS-capeIT
    # check if ACL restrictions exist
    if ( IsHashRefWithData( \%AclAction ) ) {

        # show error screen if ACL prohibits this action
        if ( defined $AclAction{ $Self->{Action} } && $AclAction{ $Self->{Action} } eq '0' ) {

            return $LayoutObject->NoPermission( WithHeader => 'yes' );
        }
    }

    if ( $Self->{Subaction} eq 'SendEmail' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        $Output = $Self->SendEmail();
    }

    # KIX4OTRS-capeIT
    # update position
    elsif ( $Self->{Subaction} eq 'UpdatePosition' ) {

        # challenge token check for write action
        $LayoutObject->ChallengeTokenCheck();

        my @Backends = $ParamObject->GetArray( Param => 'Backend' );

        # get new order
        my $Key  = $Self->{Action} . 'Position';
        my $Data = '';
        for my $Backend (@Backends) {
            $Data .= $Backend . ';';
        }

        # update ssession
        $SessionObject->UpdateSessionID(
            SessionID => $Self->{SessionID},
            Key       => $Key,
            Value     => $Data,
        );

        # update preferences
        if ( !$ConfigObject->Get('DemoSystem') ) {
            $UserObject->SetPreferences(
                UserID => $Self->{UserID},
                Key    => $Key,
                Value  => $Data,
            );
        }

        # redirect
        return $LayoutObject->Attachment(
            ContentType => 'text/html',
            Charset     => $LayoutObject->{UserCharset},
            Content     => '',
        );
    }

    # EO KIX4OTRS-capeIT
    elsif ( $Self->{Subaction} eq 'AJAXUpdateTemplate' ) {

        my %GetParam;
        for my $Key (
            qw(
            NewStateID NewPriorityID TimeUnits ArticleTypeID Title Body Subject NewQueueID
            Year Month Day Hour Minute NewOwnerID NewOwnerType OldOwnerID NewResponsibleID
            TypeID ServiceID SLAID Expand ReplyToArticle StandardTemplateID CreateArticle
            FormID ElementChanged
            )
            )
        {
            $GetParam{$Key} = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => $Key );
        }

        my %Ticket       = $TicketObject->TicketGet( TicketID => $Self->{TicketID} );
        my $CustomerUser = $Ticket{CustomerUserID};
        my $QueueID      = $Ticket{QueueID};

        # get dynamic field values form http request
        my %DynamicFieldValues;

        # convert dynamic field values into a structure for ACLs
        my %DynamicFieldACLParameters;
        DYNAMICFIELD:
        for my $DynamicFieldItem ( sort keys %DynamicFieldValues ) {
            next DYNAMICFIELD if !$DynamicFieldItem;
            next DYNAMICFIELD if !$DynamicFieldValues{$DynamicFieldItem};

            $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldItem } = $DynamicFieldValues{$DynamicFieldItem};
        }

        # get config object
        my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

        # get list type
        my $TreeView = 0;
        if ( $ConfigObject->Get('Ticket::Frontend::ListType') eq 'tree' ) {
            $TreeView = 1;
        }

        my $NextStates = $Self->_GetNextStates(
            %GetParam,
            CustomerUserID => $CustomerUser || '',
            QueueID => $QueueID,
        );

        # update Dynamic Fields Possible Values via AJAX
        my @DynamicFieldAJAX;

        # get config for frontend module
        my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

        # get the dynamic fields for this screen
        my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
            Valid       => 1,
            ObjectType  => [ 'Ticket', 'Article' ],
            FieldFilter => $Config->{DynamicField} || {},
        );

        # get dynamic field backend object
        my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

        # cycle trough the activated Dynamic Fields for this screen
        DYNAMICFIELD:
        for my $DynamicFieldConfig ( @{$DynamicField} ) {
            next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

            my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
                DynamicFieldConfig => $DynamicFieldConfig,
                Behavior           => 'IsACLReducible',
            );
            next DYNAMICFIELD if !$IsACLReducible;

            my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # convert possible values key => value to key => key for ACLs using a Hash slice
            my %AclData = %{$PossibleValues};
            @AclData{ keys %AclData } = keys %AclData;

            # set possible values filter from ACLs
            my $ACL = $TicketObject->TicketAcl(
                %GetParam,
                Action        => $Self->{Action},
                TicketID      => $Self->{TicketID},
                QueueID       => $QueueID,
                ReturnType    => 'Ticket',
                ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data          => \%AclData,
                UserID        => $Self->{UserID},
            );
            if ($ACL) {
                my %Filter = $TicketObject->TicketAclData();

                # convert Filer key => key back to key => value using map
                %{$PossibleValues} = map { $_ => $PossibleValues->{$_} } keys %Filter;
            }

            my $DataValues = $DynamicFieldBackendObject->BuildSelectionDataGet(
                DynamicFieldConfig => $DynamicFieldConfig,
                PossibleValues     => $PossibleValues,
                Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            ) || $PossibleValues;

            # add dynamic field to the list of fields to update
            push(
                @DynamicFieldAJAX,
                {
                    Name        => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data        => $DataValues,
                    SelectedID  => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                    Translation => $DynamicFieldConfig->{Config}->{TranslatableValues} || 0,
                    Max         => 100,
                }
            );
        }

        my $StandardTemplates = $Self->_GetStandardTemplates(
            %GetParam,
            QueueID => $QueueID || '',
        );

        my @TemplateAJAX;

        # get upload cache object
        my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

        # update ticket body and attachments if needed.
        if ( $GetParam{ElementChanged} eq 'StandardTemplateID' ) {
            my @TicketAttachments;
            my $TemplateText;

            # remove all attachments from the Upload cache
            my $RemoveSuccess = $UploadCacheObject->FormIDRemove(
                FormID => $GetParam{FormID},
            );
            if ( !$RemoveSuccess ) {
                $Kernel::OM->Get('Kernel::System::Log')->Log(
                    Priority => 'error',
                    Message  => "Form attachments could not be deleted!",
                );
            }

            # get the template text and set new attachments if a template is selected
            my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');

            if ( IsPositiveInteger( $GetParam{StandardTemplateID} ) ) {

                # set template text, replace smart tags (limited as ticket is not created)
                $TemplateText = $TemplateGenerator->Template(
                    TemplateID => $GetParam{StandardTemplateID},
                    TicketID   => $Self->{TicketID},
                    UserID     => $Self->{UserID},
                );

                # create StdAttachmentObject
                my $StdAttachmentObject = $Kernel::OM->Get('Kernel::System::StdAttachment');

                # add std. attachments to ticket
                my %AllStdAttachments = $StdAttachmentObject->StdAttachmentStandardTemplateMemberList(
                    StandardTemplateID => $GetParam{StandardTemplateID},
                );
                for my $ID ( sort keys %AllStdAttachments ) {
                    my %AttachmentsData = $StdAttachmentObject->StdAttachmentGet( ID => $ID );
                    $UploadCacheObject->FormIDAddFile(
                        FormID      => $GetParam{FormID},
                        Disposition => 'attachment',
                        %AttachmentsData,
                    );
                }

                # send a list of attachments in the upload cache back to the client side JavaScript
                # which renders then the list of currently uploaded attachments
                @TicketAttachments = $UploadCacheObject->FormIDGetAllFilesMeta(
                    FormID => $GetParam{FormID},
                );
            }

            # get first article of the ticket
            my %Article = $TicketObject->ArticleFirstArticle(
                TicketID      => $Self->{TicketID},
                DynamicFields => 0,
            );

            # get the matching signature for the current user
            my $Signature = $TemplateGenerator->Signature(
                TicketID  => $Self->{TicketID},
                ArticleID => $Article{ArticleID},
                Data      => \%Article,
                UserID    => $Self->{UserID},
            );

            # append the signature to the body text
            if ( $LayoutObject->{BrowserRichText} ) {
                $TemplateText = $TemplateText . '<br><br>' . $Signature;
            }
            else {
                $TemplateText = $TemplateText . "\n\n" . $Signature;
            }

            @TemplateAJAX = (
                {
                    Name => 'UseTemplateNote',
                    Data => '0',
                },
                {
                    Name => 'RichText',
                    Data => $TemplateText || '',
                },
                {
                    Name     => 'TicketAttachments',
                    Data     => \@TicketAttachments,
                    KeepData => 1,
                },
            );
        }

        my $JSON = $LayoutObject->BuildSelectionJSON(
            [
                {
                    Name         => 'NewStateID',
                    Data         => $NextStates,
                    SelectedID   => $GetParam{NewStateID},
                    Translation  => 1,
                    PossibleNone => $Config->{StateDefault} ? 0 : 1,
                    Max          => 100,
                },
                {
                    Name         => 'StandardTemplateID',
                    Data         => $StandardTemplates,
                    SelectedID   => $GetParam{StandardTemplateID},
                    PossibleNone => 1,
                    Translation  => 1,
                    Max          => 100,
                },
                @DynamicFieldAJAX,
                @TemplateAJAX,
            ],
        );

        return $LayoutObject->Attachment(
            ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
            Content     => $JSON,
            Type        => 'inline',
            NoCache     => 1,
        );
    }
    elsif ( $Self->{Subaction} eq 'AJAXUpdate' ) {
        $Output = $Self->AjaxUpdate();
    }
    else {
        $Output = $Self->Form();
    }

    return $Output;
}

sub Form {
    my ( $Self, %Param ) = @_;

    my %Error;
    my %ACLCompatGetParam;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # ACL compatibility translation
    $ACLCompatGetParam{NextStateID} = $ParamObject->GetParam( Param => 'NextStateID' );

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # check needed stuff
    if ( !$Self->{TicketID} ) {

        return $LayoutObject->ErrorScreen(
            Message => Translatable('Got no TicketID!'),
            Comment => Translatable('System Error!'),
        );
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # get ticket data
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config for frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # check permissions
    my $Access = $TicketObject->TicketPermission(
        Type     => $Config->{Permission},
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID}
    );

    # error screen, don't show ticket
    if ( !$Access ) {

        return $LayoutObject->NoPermission( WithHeader => 'yes' );
    }

    my %GetParamExtended = $Self->_GetExtendedParams();

    my %GetParam            = %{ $GetParamExtended{GetParam} };
    my @MultipleCustomer    = @{ $GetParamExtended{MultipleCustomer} };
    my @MultipleCustomerCc  = @{ $GetParamExtended{MultipleCustomerCc} };
    my @MultipleCustomerBcc = @{ $GetParamExtended{MultipleCustomerBcc} };

    # get lock state
    my $Output = '';
    if ( $Config->{RequiredLock} ) {
        if ( !$TicketObject->TicketLockGet( TicketID => $Self->{TicketID} ) ) {

            # set owner
            $TicketObject->TicketOwnerSet(
                TicketID  => $Self->{TicketID},
                UserID    => $Self->{UserID},
                NewUserID => $Self->{UserID},
            );

            # set lock
            my $Lock = $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'lock',
                UserID   => $Self->{UserID}
            );

            # show lock state
            if ($Lock) {
                $LayoutObject->Block(
                    Name => 'PropertiesLock',
                    Data => { %Param, TicketID => $Self->{TicketID} },
                );
            }
        }
        else {
            my $AccessOk = $TicketObject->OwnerCheck(
                TicketID => $Self->{TicketID},
                OwnerID  => $Self->{UserID},
            );
            if ( !$AccessOk ) {
                my $Output = $LayoutObject->Header(
                    Type      => 'Small',
                    BodyClass => 'Popup',
                );
                $Output .= $LayoutObject->Warning(
                    Message => Translatable('Sorry, you need to be the ticket owner to perform this action.'),
                    Comment => Translatable('Please change the owner first.'),
                );
                $Output .= $LayoutObject->Footer(
                    Type => 'Small',
                );

                return $Output;
            }
            else {
                $LayoutObject->Block(
                    Name => 'TicketBack',
                    Data => {
                        %Param,
                        TicketID => $Self->{TicketID},
                    },
                );
            }
        }
    }
    else {
        $LayoutObject->Block(
            Name => 'TicketBack',
            Data => {
                %Param,
                TicketID => $Self->{TicketID},
            },
        );
    }

    # get last customer article or selected article
    my %Data;
    if ( $GetParam{ArticleID} ) {
        %Data = $TicketObject->ArticleGet(
            ArticleID     => $GetParam{ArticleID},
            DynamicFields => 1,
        );

        # Check if article is from the same TicketID as we checked permissions for.
        if ( $Data{TicketID} ne $Self->{TicketID} ) {

            return $LayoutObject->ErrorScreen(
                Message => $LayoutObject->{LanguageObject}
                    ->Translate( 'Article does not belong to ticket %s!', $Self->{TicketID} ),
            );
        }
    }
    else {
        %Data = $TicketObject->ArticleLastCustomerArticle(
            TicketID      => $Self->{TicketID},
            DynamicFields => 1,
        );
    }

    # prepare signature
    my $TemplateGenerator = $Kernel::OM->Get('Kernel::System::TemplateGenerator');
    $Data{Signature} = $TemplateGenerator->Signature(
        TicketID  => $Self->{TicketID},
        ArticleID => $Data{ArticleID},
        Data      => \%Data,
        UserID    => $Self->{UserID},
    );

    if ( $GetParam{EmailTemplateID} ) {

        # get template
        $Data{StdTemplate} = $TemplateGenerator->Template(
            TicketID   => $Self->{TicketID},
            ArticleID  => $Data{ArticleID},
            TemplateID => $GetParam{EmailTemplateID},
            Data       => \%Data,
            UserID     => $Self->{UserID},
        );

        # get signature
        $Data{Signature} = $TemplateGenerator->Signature(
            TicketID => $Self->{TicketID},
            Data     => \%Data,
            UserID   => $Self->{UserID},
        );
    }

    # empty the body for preparation
    $Data{Body} = '';

    # prepare body for richtext or plaintext content
    if ( $LayoutObject->{BrowserRichText} ) {

        # add the temp
        if ( $GetParam{EmailTemplateID} ) {
            $Data{Body} = $Data{StdTemplate} . '<br/>' . $Data{Body};
        }

        $Data{Body} = $Data{Body} . $Data{Signature};
    }
    else {

        # add the temp
        if ( $GetParam{EmailTemplateID} ) {
            $Data{Body} = $Data{StdTemplate} . "\n" . $Data{Body};
        }

        $Data{Body} = $Data{Body} . $Data{Signature};

        # prepare body for plain text
        $Data{Body} =~ s/\t/ /g;
    }

    # get needed objects
    my $StdAttachmentObject = $Kernel::OM->Get('Kernel::System::StdAttachment');
    my $UploadCacheObject   = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    # add std. attachments to email
    if ( $GetParam{EmailTemplateID} ) {
        my %AllStdAttachments = $StdAttachmentObject->StdAttachmentStandardTemplateMemberList(
            StandardTemplateID => $GetParam{EmailTemplateID},
        );
        for my $ID ( sort keys %AllStdAttachments ) {
            my %AttachmentsData = $StdAttachmentObject->StdAttachmentGet( ID => $ID );
            $UploadCacheObject->FormIDAddFile(
                FormID => $GetParam{FormID},
                %AttachmentsData,
            );
        }
    }

    # get all attachments meta data
    my @Attachments = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDGetAllFilesMeta(
        FormID => $GetParam{FormID},
    );

    # check some values
    for my $Recipient (qw(To Cc Bcc Subject)) {
        if ( $Data{$Recipient} ) {
            delete $Data{$Recipient};
        }
    }

    # put & get attributes like sender address
    %Data = $TemplateGenerator->Attributes(
        TicketID  => $Self->{TicketID},
        ArticleID => $GetParam{ArticleID},
        Data      => \%Data,
        UserID    => $Self->{UserID},
    );

    # prepare the subject
    $Data{Subject} =~ s{ \A (?: .*? : \s*) }{}xms;

    # run compose modules
    if ( ref( $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') ) eq 'HASH' ) {
        my %Jobs = %{ $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') };
        for my $Job ( sort keys %Jobs ) {

            # load module
            if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Jobs{$Job}->{Module} ) ) {

                return $LayoutObject->FatalError();
            }
            my $Object = $Jobs{$Job}->{Module}->new(
                %{$Self},
                Debug => $Self->{Debug},
            );

            # get params
            for my $Param ( $Object->Option( %Data, %GetParam, Config => $Jobs{$Job} ) ) {
                $GetParam{$Param} = $ParamObject->GetParam( Param => $Param );
            }

            # run module
            $Object->Run( %Data, %GetParam, Config => $Jobs{$Job} );

            # get errors
            %Error = ( %Error, $Object->Error( %GetParam, Config => $Jobs{$Job} ) );
        }
    }

    # create HTML strings for all dynamic fields
    my %DynamicFieldHTML;

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get dynamic field backend object
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # KIX4OTRS-capeIT
        # my $PossibleValuesFilter;
        # EO KIX4OTRS-capeIT

        my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );

        if ($IsACLReducible) {

            # get PossibleValues
            my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # check if field has PossibleValues property in its configuration
            if ( IsHashRefWithData($PossibleValues) ) {

                # convert possible values key => value to key => key for ACLs using a Hash slice
                my %AclData = %{$PossibleValues};
                @AclData{ keys %AclData } = keys %AclData;

                # set possible values filter from ACLs
                my $ACL = $TicketObject->TicketAcl(
                    %GetParam,
                    %ACLCompatGetParam,
                    Action        => $Self->{Action},
                    TicketID      => $Self->{TicketID},
                    ReturnType    => 'Ticket',
                    ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data          => \%AclData,
                    UserID        => $Self->{UserID},
                );
                if ($ACL) {
                    my %Filter = $TicketObject->TicketAclData();

                    # convert Filer key => key back to key => value using map
                    # KIX4OTRS-capeIT
                    # %{$PossibleValuesFilter} = map { $_ => $PossibleValues->{$_} }
                    %{ $DynamicFieldConfig->{ShownPossibleValues} }
                        = map { $_ => $PossibleValues->{$_} }

                        # EO KIX4OTRS-capeIT
                        keys %Filter;
                }
            }
        }

        # to store dynamic field value from database (or undefined)
        my $Value;

        # only get values for Ticket fields (all screens based on AgentTickeActionCommon
        # create a new article, then article fields will be always empty at the beginning)
        if ( $DynamicFieldConfig->{ObjectType} eq 'Ticket' ) {

            # get value stored on the database from Ticket
            $Value = $Ticket{ 'DynamicField_' . $DynamicFieldConfig->{Name} };
        }

        # get field HTML
        $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
            $DynamicFieldBackendObject->EditFieldRender(
            DynamicFieldConfig => $DynamicFieldConfig,

            # KIX4OTRS-capeIT
            # PossibleValuesFilter => $PossibleValuesFilter,
            PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},

            # EO KIX4OTRS-capeIT
            Value => $Value,
            Mandatory =>
                $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
            LayoutObject    => $LayoutObject,
            ParamObject     => $ParamObject,
            AJAXUpdate      => 1,
            UpdatableFields => $Self->_GetFieldsToUpdate(),
            );
    }

    # KIX4OTRS-capeIT
    # get shown or hidden fields
    $Self->_GetShownDynamicFields();

    # EO KIX4OTRS-capeIT

    # build view ...
    # start with page ...
    $Output .= $LayoutObject->Header(
        Value     => $Ticket{TicketNumber},
        Type      => 'Small',
        BodyClass => 'Popup',
    );

    $Output .= $Self->_Mask(
        TicketNumber => $Ticket{TicketNumber},
        TicketID     => $Self->{TicketID},
        Title        => $Ticket{Title},
        QueueID      => $Ticket{QueueID},
        NextStates   => $Self->_GetNextStates(
            %GetParam,
            %ACLCompatGetParam,
        ),
        TimeUnitsRequired => (
            $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
            ? 'Validate_Required'
            : ''
        ),
        Errors              => \%Error,
        MultipleCustomer    => \@MultipleCustomer,
        MultipleCustomerCc  => \@MultipleCustomerCc,
        MultipleCustomerBcc => \@MultipleCustomerBcc,
        Attachments         => \@Attachments,
        %Data,
        %GetParam,
        DynamicFieldHTML => \%DynamicFieldHTML,
    );
    $Output .= $LayoutObject->Footer(
        Type => 'Small',
    );

    return $Output;
}

sub SendEmail {
    my ( $Self, %Param ) = @_;

    my %Error;
    my %ACLCompatGetParam;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # ACL compatibility translation
    $ACLCompatGetParam{NextStateID} = $ParamObject->GetParam( Param => 'NextStateID' );

    my %GetParamExtended = $Self->_GetExtendedParams();

    my %GetParam            = %{ $GetParamExtended{GetParam} };
    my @MultipleCustomer    = @{ $GetParamExtended{MultipleCustomer} };
    my @MultipleCustomerCc  = @{ $GetParamExtended{MultipleCustomerCc} };
    my @MultipleCustomerBcc = @{ $GetParamExtended{MultipleCustomerBcc} };

    my %DynamicFieldValues;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config for frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get needed objects
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $LayoutObject              = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} } =
            $DynamicFieldBackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
            );
    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicFieldItem ( sort keys %DynamicFieldValues ) {
        next DYNAMICFIELD if !$DynamicFieldItem;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicFieldItem};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldItem } = $DynamicFieldValues{$DynamicFieldItem};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    my $QueueID = $Self->{QueueID};
    my %StateData;

    if ( $GetParam{ComposeStateID} ) {
        %StateData = $Kernel::OM->Get('Kernel::System::State')->StateGet(
            ID => $GetParam{ComposeStateID},
        );
    }

    my $NextState = $StateData{Name};

    # get time object
    my $TimeObject = $Kernel::OM->Get('Kernel::System::Time');

    # check pending date
    if ( defined $StateData{TypeName} && $StateData{TypeName} =~ /^pending/i ) {
        if ( !$TimeObject->Date2SystemTime( %GetParam, Second => 0 ) ) {
            $Error{'DateInvalid'} = 'ServerError';
        }
        if (
            $TimeObject->Date2SystemTime( %GetParam, Second => 0 )
            < $TimeObject->SystemTime()
            )
        {
            $Error{'DateInvalid'} = 'ServerError';
        }
    }

    # check To
    if ( !$GetParam{To} ) {
        $Error{'ToInvalid'} = 'ServerError';
    }

    # check body
    if ( !$GetParam{Body} ) {
        $Error{'BodyInvalid'} = 'ServerError';
    }

    # check subject
    if ( !$GetParam{Subject} ) {
        $Error{'SubjectInvalid'} = 'ServerError';
    }

    if (
        $ConfigObject->Get('Ticket::Frontend::AccountTime')
        && $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime')
        && $GetParam{TimeUnits} eq ''
        )
    {
        $Error{'TimeUnitsInvalid'} = 'ServerError';
    }

    # get ticket object
    my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

    # prepare subject
    my %Ticket = $TicketObject->TicketGet(
        TicketID      => $Self->{TicketID},
        DynamicFields => 1,
    );

    # create HTML strings for all dynamic fields
    my $IsUpload = 0;

    # attachment delete
    my @AttachmentIDs = map {
        my ($ID) = $_ =~ m{ \A AttachmentDelete (\d+) \z }xms;
        $ID ? $ID : ();
    } $ParamObject->GetParamNames();

    # get upload cache object
    my $UploadCacheObject = $Kernel::OM->Get('Kernel::System::Web::UploadCache');

    COUNT:
    for my $Count ( reverse sort @AttachmentIDs ) {
        my $Delete = $ParamObject->GetParam( Param => "AttachmentDelete$Count" );
        next COUNT if !$Delete;
        %Error = ();
        $Error{AttachmentDelete} = 1;
        $UploadCacheObject->FormIDRemoveFile(
            FormID => $GetParam{FormID},
            FileID => $Count,
        );
        $IsUpload = 1;
    }

    # attachment upload
    if ( $ParamObject->GetParam( Param => 'AttachmentUpload' ) ) {
        $IsUpload                = 1;
        %Error                   = ();
        $Error{AttachmentUpload} = 1;
        my %UploadStuff = $ParamObject->GetUploadAll(
            Param => 'FileUpload',
        );
        $UploadCacheObject->FormIDAddFile(
            FormID => $GetParam{FormID},
            %UploadStuff,
        );
    }

    # get all attachments meta data
    my @Attachments = $UploadCacheObject->FormIDGetAllFilesMeta(
        FormID => $GetParam{FormID},
    );

    # create HTML strings for all dynamic fields
    my %DynamicFieldHTML;

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $PossibleValuesFilter;

        my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );

        if ($IsACLReducible) {

            # get PossibleValues
            my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
                DynamicFieldConfig => $DynamicFieldConfig,
            );

            # check if field has PossibleValues property in its configuration
            if ( IsHashRefWithData($PossibleValues) ) {

                # convert possible values key => value to key => key for ACLs using a Hash slice
                my %AclData = %{$PossibleValues};
                @AclData{ keys %AclData } = keys %AclData;

                # set possible values filter from ACLs
                my $ACL = $TicketObject->TicketAcl(
                    %GetParam,
                    %ACLCompatGetParam,
                    Action        => $Self->{Action},
                    TicketID      => $Self->{TicketID},
                    ReturnType    => 'Ticket',
                    ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
                    Data          => \%AclData,
                    UserID        => $Self->{UserID},
                );
                if ($ACL) {
                    my %Filter = $TicketObject->TicketAclData();

                    # convert Filer key => key back to key => value using map
                    # KIX4OTRS-capeIT
                    # %{$PossibleValuesFilter} = map { $_ => $PossibleValues->{$_} }
                    %{ $DynamicFieldConfig->{ShownPossibleValues} }
                        = map { $_ => $PossibleValues->{$_} }

                        # EO KIX4OTRS-capeIT
                        keys %Filter;
                }
            }
        }

        # KIX4OTRS-capeIT
    }

    # get shown or hidden fields
    $Self->_GetShownDynamicFields();

    # cycle trough the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # EO KIX4OTRS-capeIT

        my $ValidationResult;

        # do not validate if field is disabled
        if ( !$DynamicFieldConfig->{Shown} ) {

            if ( !$IsUpload ) {

                $ValidationResult = $DynamicFieldBackendObject->EditFieldValueValidate(

                    # EO KIX4OTRS-capeIT
                    DynamicFieldConfig => $DynamicFieldConfig,

                    # KIX4OTRS-capeIT
                    # PossibleValuesFilter => $PossibleValuesFilter,
                    PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},

                    # EO KIX4OTRS-capeIT
                    ParamObject => $ParamObject,
                    Mandatory =>
                        $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                );

                if ( !IsHashRefWithData($ValidationResult) ) {

                    return $LayoutObject->ErrorScreen(
                        Message =>
                            $LayoutObject->{LanguageObject}
                            ->Translate( 'Could not perform validation on field %s!', $DynamicFieldConfig->{Label} ),
                        Comment => Translatable('Please contact the admin.'),
                    );
                }

                # propagate validation error to the Error variable to be detected by the frontend
                if ( $ValidationResult->{ServerError} ) {
                    $Error{ $DynamicFieldConfig->{Name} } = ' ServerError';
                }
            }

            # get field HTML
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig => $DynamicFieldConfig,

                # KIX4OTRS-capeIT
                # PossibleValuesFilter => $PossibleValuesFilter,
                PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},

                # EO KIX4OTRS-capeIT
                Mandatory =>
                    $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                ServerError  => $ValidationResult->{ServerError}  || '',
                ErrorMessage => $ValidationResult->{ErrorMessage} || '',
                LayoutObject => $LayoutObject,
                ParamObject  => $ParamObject,
                AJAXUpdate   => 1,
                UpdatableFields => $Self->_GetFieldsToUpdate(),
                );
        }
    }

    # transform pending time, time stamp based on user time zone
    if (
        defined $GetParam{Year}
        && defined $GetParam{Month}
        && defined $GetParam{Day}
        && defined $GetParam{Hour}
        && defined $GetParam{Minute}
        )
    {
        %GetParam = $LayoutObject->TransformDateSelection(
            %GetParam,
        );
    }

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

    # check some values
    LINE:
    for my $Line (qw(To Cc Bcc)) {
        next LINE if !$GetParam{$Line};
        for my $Email ( Mail::Address->parse( $GetParam{$Line} ) ) {
            if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                $Error{ $Line . 'ErrorType' }
                    = $Line . $CheckItemObject->CheckErrorType() . 'ServerErrorMsg';
                $Error{ "$Line" . "Invalid" } = 'ServerError';
            }

            if ($ConfigObject->Get('CheckEmailInternalAddress')) {
                my $IsLocal = $Kernel::OM->Get('Kernel::System::SystemAddress')->SystemAddressIsLocalAddress(
                    Address => $Email->address()
                );
                if ($IsLocal) {
                    $Error{ "$Line" . 'IsLocalAddress' } = 'ServerError';
                }
            }
        }
    }

    # run compose modules
    my %ArticleParam;

    if ( ref( $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') ) eq 'HASH' ) {
        my %Jobs = %{ $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') };
        for my $Job ( sort keys %Jobs ) {

            # load module
            if ( !$Kernel::OM->Get('Kernel::System::Main')->Require( $Jobs{$Job}->{Module} ) ) {
                return $LayoutObject->FatalError();
            }
            my $Object = $Jobs{$Job}->{Module}->new(
                %{$Self},
                Debug => $Self->{Debug},
            );

            # get params
            for my $Param ( $Object->Option( %GetParam, Config => $Jobs{$Job} ) ) {
                $GetParam{$Param} = $ParamObject->GetParam( Param => $Param );
            }

            # run module
            $Object->Run( %GetParam, Config => $Jobs{$Job} );

            # ticket params
            %ArticleParam = (
                %ArticleParam,
                $Object->ArticleOption( %GetParam, Config => $Jobs{$Job} ),
            );

            # get errors
            %Error = (
                %Error,
                $Object->Error( %GetParam, Config => $Jobs{$Job} ),
            );
        }
    }

    # check if there is an error
    if (%Error) {

        my $QueueID = $TicketObject->TicketQueueID( TicketID => $Self->{TicketID} );
        my $Output = $LayoutObject->Header(
            Type      => 'Small',
            BodyClass => 'Popup',
        );
        $Output .= $Self->_Mask(
            TicketNumber => $Ticket{TicketNumber},
            Title        => $Ticket{Title},
            TicketID     => $Self->{TicketID},
            QueueID      => $QueueID,
            NextStates   => $Self->_GetNextStates(
                %GetParam,
                %ACLCompatGetParam,
            ),
            Errors              => \%Error,
            MultipleCustomer    => \@MultipleCustomer,
            MultipleCustomerCc  => \@MultipleCustomerCc,
            MultipleCustomerBcc => \@MultipleCustomerBcc,
            Attachments         => \@Attachments,
            DynamicFieldHTML    => \%DynamicFieldHTML,
            %GetParam,
        );
        $Output .= $LayoutObject->Footer(
            Type => 'Small',
        );
        return $Output;
    }

#rbo - T2016121190001552 - added KIX placeholders
    # replace <KIX_TICKET_STATE> with next ticket state name
    if ($NextState) {
        $GetParam{Body} =~ s/(&lt;|<)KIX_TICKET_STATE(&gt;|>)/$NextState/g;
    }

    # get pre loaded attachments
    my @AttachmentData = $UploadCacheObject->FormIDGetAllFilesData(
        FormID => $GetParam{FormID},
    );

    # get submit attachment
    my %UploadStuff = $ParamObject->GetUploadAll(
        Param => 'FileUpload',
    );
    if (%UploadStuff) {
        push @AttachmentData, \%UploadStuff;
    }

    my $MimeType = 'text/plain';
    if ( $LayoutObject->{BrowserRichText} ) {
        $MimeType = 'text/html';

        # remove unused inline images
        my @NewAttachmentData;

        ATTACHMENT:
        for my $Attachment (@AttachmentData) {
            my $ContentID = $Attachment->{ContentID};
            if ( $ContentID && ( $Attachment->{ContentType} =~ /image/i ) ) {
                my $ContentIDHTMLQuote = $LayoutObject->Ascii2Html(
                    Text => $ContentID,
                );

                # workaround for link encode of rich text editor, see bug#5053
                my $ContentIDLinkEncode = $LayoutObject->LinkEncode($ContentID);
                $GetParam{Body} =~ s/(ContentID=)$ContentIDLinkEncode/$1$ContentID/g;

                # ignore attachment if not linked in body
                next ATTACHMENT if $GetParam{Body} !~ /(\Q$ContentIDHTMLQuote\E|\Q$ContentID\E)/i;
            }

            # remember inline images and normal attachments
            push @NewAttachmentData, \%{$Attachment};
        }
        @AttachmentData = @NewAttachmentData;

        # verify HTML document
        $GetParam{Body} = $LayoutObject->RichTextDocumentComplete(
            String => $GetParam{Body},
        );
    }

    # send email
    my $To = '';

    KEY:
    for my $Key (qw(To Cc Bcc)) {
        next KEY if !$GetParam{$Key};
        if ($To) {
            $To .= ', ';
        }
        $To .= $GetParam{$Key}
    }

    # get article type ID param
    my $ArticleTypeID = $ParamObject->GetParam( Param => 'ArticleTypeID' );

    my $ArticleID = $TicketObject->ArticleSend(
        ArticleTypeID  => $ArticleTypeID,
        SenderType     => 'agent',
        TicketID       => $Self->{TicketID},
        HistoryType    => 'EmailAgent',
        HistoryComment => "\%\%$To",
        From           => $GetParam{From},
        To             => $GetParam{To},
        Cc             => $GetParam{Cc},
        Bcc            => $GetParam{Bcc},
        Subject        => $GetParam{Subject},
        UserID         => $Self->{UserID},
        Body           => $GetParam{Body},

        # We start a new communication here, so don't send any references.
        #   This might lead to information disclosure (domain names; see bug#11246).
        InReplyTo  => '',
        References => '',
        Charset    => $LayoutObject->{UserCharset},
        MimeType   => $MimeType,
        Attachment => \@AttachmentData,
        %ArticleParam,
    );

    # error page
    if ( !$ArticleID ) {

        return $LayoutObject->ErrorScreen(
            Comment => Translatable('Please contact the administrator.'),
        );
    }

    # time accounting
    if ( $GetParam{TimeUnits} ) {
        $TicketObject->TicketAccountTime(
            TicketID  => $Self->{TicketID},
            ArticleID => $ArticleID,
            TimeUnit  => $GetParam{TimeUnits},
            UserID    => $Self->{UserID},
        );
    }

    # set dynamic fields
    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # set the object ID (TicketID or ArticleID) depending on the field configuration
        my $ObjectID = $DynamicFieldConfig->{ObjectType} eq 'Article' ? $ArticleID : $Self->{TicketID};

        # set the value
        my $Success = $DynamicFieldBackendObject->ValueSet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ObjectID           => $ObjectID,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
            UserID             => $Self->{UserID},
        );
    }

    # set state
    if ($NextState) {
        $TicketObject->TicketStateSet(
            TicketID  => $Self->{TicketID},
            ArticleID => $ArticleID,
            State     => $NextState,
            UserID    => $Self->{UserID},
        );

        # should I set an unlock?
        if ( $StateData{TypeName} =~ /^close/i ) {
            $TicketObject->TicketLockSet(
                TicketID => $Self->{TicketID},
                Lock     => 'unlock',
                UserID   => $Self->{UserID},
            );
        }

        # set pending time
        elsif ( $StateData{TypeName} =~ /^pending/i ) {
            $TicketObject->TicketPendingTimeSet(
                UserID   => $Self->{UserID},
                TicketID => $Self->{TicketID},
                %GetParam,
            );
        }
    }

    # remove pre-submitted attachments
    $UploadCacheObject->FormIDRemove( FormID => $GetParam{FormID} );

    # redirect
    if ( defined $StateData{TypeName} && $StateData{TypeName} =~ /^close/i ) {

        return $LayoutObject->PopupClose(
            URL => ( $Self->{LastScreenOverview} || 'Action=AgentDashboard' ),
        );
    }

    return $LayoutObject->PopupClose(
        URL => "Action=AgentTicketZoom;TicketID=$Self->{TicketID};ArticleID=$ArticleID",
    );
}

sub AjaxUpdate {
    my ( $Self, %Param ) = @_;

    my %Error;
    my %ACLCompatGetParam;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # ACL compatibility translation
    $ACLCompatGetParam{NextStateID} = $ParamObject->GetParam( Param => 'NextStateID' );

    my %GetParamExtended = $Self->_GetExtendedParams();

    my %GetParam            = %{ $GetParamExtended{GetParam} };
    my @MultipleCustomer    = @{ $GetParamExtended{MultipleCustomer} };
    my @MultipleCustomerCc  = @{ $GetParamExtended{MultipleCustomerCc} };
    my @MultipleCustomerBcc = @{ $GetParamExtended{MultipleCustomerBcc} };

    my @ExtendedData;

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # run compose modules
    if ( ref $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') eq 'HASH' ) {
        my %Jobs = %{ $ConfigObject->Get('Ticket::Frontend::ArticleComposeModule') };

        JOB:
        for my $Job ( sort keys %Jobs ) {

            # load module
            next JOB if !$Kernel::OM->Get('Kernel::System::Main')->Require( $Jobs{$Job}->{Module} );

            my $Object = $Jobs{$Job}->{Module}->new(
                %{$Self},
                Debug => $Self->{Debug},
            );

            # get params
            for my $Parameter ( $Object->Option( %GetParam, Config => $Jobs{$Job} ) ) {
                $GetParam{$Parameter} = $ParamObject->GetParam( Param => $Parameter );
            }

            # run module
            my %Data = $Object->Data( %GetParam, Config => $Jobs{$Job} );

            my $Key = $Object->Option( %GetParam, Config => $Jobs{$Job} );
            if ($Key) {
                push(
                    @ExtendedData,
                    {
                        Name        => $Key,
                        Data        => \%Data,
                        SelectedID  => $GetParam{$Key},
                        Translation => 1,
                        Max         => 100,
                    }
                );
            }
        }
    }

    my %DynamicFieldValues;

    # get config for frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # get needed objects
    my $DynamicFieldBackendObject = $Kernel::OM->Get('Kernel::System::DynamicField::Backend');
    my $LayoutObject              = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # extract the dynamic field value form the web request
        $DynamicFieldValues{ $DynamicFieldConfig->{Name} } =
            $DynamicFieldBackendObject->EditFieldValueGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            ParamObject        => $ParamObject,
            LayoutObject       => $LayoutObject,
            );
    }

    # convert dynamic field values into a structure for ACLs
    my %DynamicFieldACLParameters;
    DYNAMICFIELD:
    for my $DynamicFieldItem ( sort keys %DynamicFieldValues ) {
        next DYNAMICFIELD if !$DynamicFieldItem;
        next DYNAMICFIELD if !$DynamicFieldValues{$DynamicFieldItem};

        $DynamicFieldACLParameters{ 'DynamicField_' . $DynamicFieldItem } = $DynamicFieldValues{$DynamicFieldItem};
    }
    $GetParam{DynamicField} = \%DynamicFieldACLParameters;

    my $NextStates = $Self->_GetNextStates(
        %GetParam,
        %ACLCompatGetParam,
    );

    # update Dynamic Fields Possible Values via AJAX
    my @DynamicFieldAJAX;

    # KIX4OTRS-capeIT
    my %DynamicFieldHTML;

    # EO KIX4OTRS-capeIT

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsACLReducible = $DynamicFieldBackendObject->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );

        # KIX4OTRS-capeIT
        # next DYNAMICFIELD if !$IsACLReducible;
        if ( !$IsACLReducible ) {
            $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
                $DynamicFieldBackendObject->EditFieldRender(
                DynamicFieldConfig => $DynamicFieldConfig,
                Mandatory =>
                    $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
                LayoutObject    => $LayoutObject,
                ParamObject     => $ParamObject,
                AJAXUpdate      => 0,
                UpdatableFields => $Self->_GetFieldsToUpdate(),
                UseDefaultValue => 1,
                );
            next DYNAMICFIELD;
        }

        # EO KIX4OTRS-capeIT

        my $PossibleValues = $DynamicFieldBackendObject->PossibleValuesGet(
            DynamicFieldConfig => $DynamicFieldConfig,
        );

        # convert possible values key => value to key => key for ACLs using a Hash slice
        my %AclData = %{$PossibleValues};
        @AclData{ keys %AclData } = keys %AclData;

        # get ticket object
        my $TicketObject = $Kernel::OM->Get('Kernel::System::Ticket');

        # set possible values filter from ACLs
        my $ACL = $TicketObject->TicketAcl(
            %GetParam,
            %ACLCompatGetParam,
            Action        => $Self->{Action},
            TicketID      => $Self->{TicketID},
            QueueID       => $Self->{QueueID},
            ReturnType    => 'Ticket',
            ReturnSubType => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data          => \%AclData,
            UserID        => $Self->{UserID},
        );
        if ($ACL) {
            my %Filter = $TicketObject->TicketAclData();

            # convert Filer key => key back to key => value using map
            %{$PossibleValues} = map { $_ => $PossibleValues->{$_} } keys %Filter;
        }

        my $DataValues = $DynamicFieldBackendObject->BuildSelectionDataGet(
            DynamicFieldConfig => $DynamicFieldConfig,
            PossibleValues     => $PossibleValues,
            Value              => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
        ) || $PossibleValues;

        # KIX4OTRS-capeIT
        $DynamicFieldHTML{ $DynamicFieldConfig->{Name} } =
            $DynamicFieldBackendObject->EditFieldRender(
            DynamicFieldConfig   => $DynamicFieldConfig,
            PossibleValuesFilter => $DynamicFieldConfig->{ShownPossibleValues},
            Mandatory =>
                $Config->{DynamicField}->{ $DynamicFieldConfig->{Name} } == 2,
            LayoutObject    => $LayoutObject,
            ParamObject     => $ParamObject,
            AJAXUpdate      => 1,
            UpdatableFields => $Self->_GetFieldsToUpdate(),
            UseDefaultValue => 1,
            );

        # EO KIX4OTRS-capeIT

        # add dynamic field to the list of fields to update
        push(
            @DynamicFieldAJAX,
            {
                Name        => 'DynamicField_' . $DynamicFieldConfig->{Name},
                Data        => $DataValues,
                SelectedID  => $DynamicFieldValues{ $DynamicFieldConfig->{Name} },
                Translation => $DynamicFieldConfig->{Config}->{TranslatableValues} || 0,
                Max         => 100,
            }
        );
    }

    # KIX4OTRS-capeIT
    # get shown or hidden fields
    $Self->_GetShownDynamicFields();

    # use only dynamic fields which passed the acl
    my %Output;
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{ $Self->{DynamicField} } ) {
        next DYNAMICFIELD if $DynamicFieldConfig->{ObjectType} ne 'Ticket';

        if ( $DynamicFieldConfig->{Shown} == 1 ) {

            $Output{ ( "DynamicField_" . $DynamicFieldConfig->{Name} ) } = (
                $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{Label}
                    . qq~\n<div class="Field">~
                    . $DynamicFieldHTML{ $DynamicFieldConfig->{Name} }->{Field}
                    . qq~\n</div>\n<div class="Clear"></div>\n~
            );
        }
        else {
            $Output{ ( "DynamicField_" . $DynamicFieldConfig->{Name} ) } = "";
        }
    }

    my @FormDisplayOutput;
    if ( IsHashRefWithData( \%Output ) ) {
        push @FormDisplayOutput, {
            Name => 'FormDisplay',
            Data => \%Output,
            Max  => 10000,
        };
    }

    # EO KIX4OTRS-capeIT
    my $JSON = $LayoutObject->BuildSelectionJSON(
        [
            {
                Name         => 'ComposeStateID',
                Data         => $NextStates,
                SelectedID   => $GetParam{ComposeStateID},
                Translation  => 1,
                PossibleNone => 1,
                Max          => 100,
            },
            @ExtendedData,
            @DynamicFieldAJAX,

            # KIX4OTRS-capeIT
            @FormDisplayOutput,

            # EO KIX4OTRS-capeIT
        ],
    );

    return $LayoutObject->Attachment(
        ContentType => 'application/json; charset=' . $LayoutObject->{Charset},
        Content     => $JSON,
        Type        => 'inline',
        NoCache     => 1,
    );
}

sub _GetNextStates {
    my ( $Self, %Param ) = @_;

    # get next states
    my %NextStates = $Kernel::OM->Get('Kernel::System::Ticket')->TicketStateList(
        %Param,
        Action   => $Self->{Action},
        TicketID => $Self->{TicketID},
        UserID   => $Self->{UserID},
    );

    return \%NextStates;
}

sub _Mask {
    my ( $Self, %Param ) = @_;

    my $DynamicFieldNames = $Self->_GetFieldsToUpdate(
        OnlyDynamicFields => 1
    );

    # create a string with the quoted dynamic field names separated by commas
    if ( IsArrayRefWithData($DynamicFieldNames) ) {
        for my $Field ( @{$DynamicFieldNames} ) {
            $Param{DynamicFieldNamesStrg} .= ", '" . $Field . "'";
        }
    }

    # get config object
    my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

    # get config for frontend module
    my $Config = $ConfigObject->Get("Ticket::Frontend::$Self->{Action}");

    # build next states string
    my %State;
    if ( !$Param{ComposeStateID} ) {
        $State{SelectedValue} = $Config->{StateDefault};
    }
    else {
        $State{SelectedID} = $Param{ComposeStateID};
    }

    # get layout object
    my $LayoutObject = $Kernel::OM->Get('Kernel::Output::HTML::Layout');

    $Param{NextStatesStrg} = $LayoutObject->BuildSelection(
        Data         => $Param{NextStates},
        Name         => 'ComposeStateID',
        PossibleNone => 1,
        Class        => 'Modernize',
        %State,
    );
    my %ArticleTypes;
    my @ArticleTypesPossible = @{ $Config->{ArticleTypes} };
    for my $ArticleType (@ArticleTypesPossible) {
        $ArticleTypes{ $Kernel::OM->Get('Kernel::System::Ticket')->ArticleTypeLookup( ArticleType => $ArticleType ) }
            = $ArticleType;
    }

    # get article type ID param
    my $ArticleTypeID = $Kernel::OM->Get('Kernel::System::Web::Request')->GetParam( Param => 'ArticleTypeID' );

    if ($ArticleTypeID) {
        $Param{ArticleTypesStrg} = $LayoutObject->BuildSelection(
            Data       => \%ArticleTypes,
            Name       => 'ArticleTypeID',
            SelectedID => $ArticleTypeID,
            Class      => 'Modernize',
        );
    }
    else {
        $Param{ArticleTypesStrg} = $LayoutObject->BuildSelection(
            Data          => \%ArticleTypes,
            Name          => 'ArticleTypeID',
            SelectedValue => $Config->{ArticleTypeDefault},
            Class         => 'Modernize',
        );
    }

    # build customer search autocomplete field
    $LayoutObject->Block(
        Name => 'CustomerSearchAutoComplete',
    );

    # prepare errors!
    if ( $Param{Errors} ) {
        for my $Error ( sort keys %{ $Param{Errors} } ) {
            $Param{$Error} = $LayoutObject->Ascii2Html( Text => $Param{Errors}->{$Error} );
        }
    }

    # pending data string
    $Param{PendingDateString} = $LayoutObject->BuildDateSelection(
        %Param,
        YearPeriodPast       => 0,
        YearPeriodFuture     => 5,
        Format               => 'DateInputFormatLong',
        DiffTime             => $ConfigObject->Get('Ticket::Frontend::PendingDiffTime') || 0,
        Class                => $Param{Errors}->{DateInvalid} || ' ',
        Validate             => 1,
        ValidateDateInFuture => 1,
    );

    # Multiple-Autocomplete
    # Cc
    my $CustomerCounterCc = 0;
    if ( $Param{MultipleCustomerCc} ) {
        for my $Item ( @{ $Param{MultipleCustomerCc} } ) {
            $LayoutObject->Block(
                Name => 'CcMultipleCustomer',
                Data => $Item,
            );
            $LayoutObject->Block(
                Name => 'Cc' . $Item->{CustomerErrorMsg},
                Data => $Item,
            );
            if ( $Item->{CustomerError} ) {
                $LayoutObject->Block(
                    Name => 'CcCustomerErrorExplantion',
                );
            }
            $CustomerCounterCc++;
        }
    }

    if ( !$CustomerCounterCc ) {
        $Param{CcCustomerHiddenContainer} = 'Hidden';
    }

    # set customer counter
    $LayoutObject->Block(
        Name => 'CcMultipleCustomerCounter',
        Data => {
            CustomerCounter => $CustomerCounterCc++,
        },
    );

    # Bcc
    my $CustomerCounterBcc = 0;
    if ( $Param{MultipleCustomerBcc} ) {
        for my $Item ( @{ $Param{MultipleCustomerBcc} } ) {
            $LayoutObject->Block(
                Name => 'BccMultipleCustomer',
                Data => $Item,
            );
            $LayoutObject->Block(
                Name => 'Bcc' . $Item->{CustomerErrorMsg},
                Data => $Item,
            );
            if ( $Item->{CustomerError} ) {
                $LayoutObject->Block(
                    Name => 'BccCustomerErrorExplantion',
                );
            }
            $CustomerCounterBcc++;
        }
    }

    if ( !$CustomerCounterBcc ) {
        $Param{BccCustomerHiddenContainer} = 'Hidden';
    }

    # set customer counter
    $LayoutObject->Block(
        Name => 'BccMultipleCustomerCounter',
        Data => {
            CustomerCounter => $CustomerCounterBcc++,
        },
    );

    # To
    my $CustomerCounter = 0;
    if ( $Param{MultipleCustomer} ) {
        for my $Item ( @{ $Param{MultipleCustomer} } ) {
            $LayoutObject->Block(
                Name => 'MultipleCustomer',
                Data => $Item,
            );
            $LayoutObject->Block(
                Name => $Item->{CustomerErrorMsg},
                Data => $Item,
            );
            if ( $Item->{CustomerError} ) {
                $LayoutObject->Block(
                    Name => 'CustomerErrorExplantion',
                );
            }
            $CustomerCounter++;
        }
    }

    if ( !$CustomerCounter ) {
        $Param{CustomerHiddenContainer} = 'Hidden';
    }

    # set customer counter
    $LayoutObject->Block(
        Name => 'MultipleCustomerCounter',
        Data => {
            CustomerCounter => $CustomerCounter++,
        },
    );

    if ( $Param{ToInvalid} && $Param{Errors} && !$Param{Errors}->{ToErrorType} ) {
        $LayoutObject->Block(
            Name => 'ToServerErrorMsg',
        );
    }

    if ( $Param{ToIsLocalAddress} && $Param{Errors} && !$Param{Errors}->{ToErrorType} ) {
        $LayoutObject->Block(
            Name => 'ToIsLocalAddressServerErrorMsg',
            Data => \%Param,
        );
    }

    if ( $Param{CcInvalid} && $Param{Errors} && !$Param{Errors}->{CcErrorType} ) {
        $LayoutObject->Block(
            Name => 'CcServerErrorMsg',
        );
    }

    if ( $Param{CcIsLocalAddress} && $Param{Errors} && !$Param{Errors}->{CcErrorType} ) {
        $LayoutObject->Block(
            Name => 'CcIsLocalAddressServerErrorMsg',
            Data => \%Param,
        );
    }

    if ( $Param{BccInvalid} && $Param{Errors} && !$Param{Errors}->{BccErrorType} ) {
        $LayoutObject->Block(
            Name => 'BccServerErrorMsg',
        );
    }

    if ( $Param{BccIsLocalAddress} && $Param{Errors} && !$Param{Errors}->{BccErrorType} ) {
        $LayoutObject->Block(
            Name => 'BccIsLocalAddressServerErrorMsg',
            Data => \%Param,
        );
    }

    # KIX4OTRS-capeIT
    $Param{KIXSidebarContent} = $LayoutObject->AgentKIXSidebar(%Param);

    # EO KIX4OTRS-capeIT

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # Dynamic fields
    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        # skip fields that HTML could not be retrieved
        next DYNAMICFIELD if !IsHashRefWithData(
            $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} }
        );

        # get the HTML strings form $Param
        my $DynamicFieldHTML = $Param{DynamicFieldHTML}->{ $DynamicFieldConfig->{Name} };

        # KIX4OTRS-capeIT
        my $Class = "";
        if ( !$DynamicFieldConfig->{Shown} ) {
            $Class = " Hidden";
            $DynamicFieldHTML->{Field} =~ s/Validate_Required//ig;
            $DynamicFieldHTML->{Field} =~ s/<(input|select|textarea)(.*?)(!?|\/)>/<$1$2 disabled="disabled"$3>/g;
        }

        # EO KIX4OTRS-capeIT

        $LayoutObject->Block(
            Name => 'DynamicField',
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},

                # KIX4OTRS-capeIT
                Class => $Class,

                # EO KIX4OTRS-capeIT
            },
        );

        # example of dynamic fields order customization
        $LayoutObject->Block(
            Name => 'DynamicField_' . $DynamicFieldConfig->{Name},
            Data => {
                Name  => $DynamicFieldConfig->{Name},
                Label => $DynamicFieldHTML->{Label},
                Field => $DynamicFieldHTML->{Field},
            },
        );
    }

    # show time accounting box
    if ( $ConfigObject->Get('Ticket::Frontend::AccountTime') ) {
        if ( $ConfigObject->Get('Ticket::Frontend::NeedAccountedTime') ) {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabelMandatory',
                Data => \%Param,
            );
        }
        else {
            $LayoutObject->Block(
                Name => 'TimeUnitsLabel',
                Data => \%Param,
            );
        }
        $LayoutObject->Block(
            Name => 'TimeUnits',
            Data => \%Param,
        );
    }

    my $ShownOptionsBlock;

    # show spell check
    if ( $LayoutObject->{BrowserSpellChecker} ) {

        # check if need to call Options block
        if ( !$ShownOptionsBlock ) {
            $LayoutObject->Block(
                Name => 'TicketOptions',
                Data => {},
            );

            # set flag to "true" in order to prevent calling the Options block again
            $ShownOptionsBlock = 1;
        }

        $LayoutObject->Block(
            Name => 'SpellCheck',
            Data => {},
        );
    }

    # show address book
    if ( $LayoutObject->{BrowserJavaScriptSupport} ) {

        # check if need to call Options block
        if ( !$ShownOptionsBlock ) {
            $LayoutObject->Block(
                Name => 'TicketOptions',
                Data => {},
            );

            # set flag to "true" in order to prevent calling the Options block again
            $ShownOptionsBlock = 1;
        }

        $LayoutObject->Block(
            Name => 'AddressBook',
            Data => {},
        );
    }

    # build text template string
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::StandardTemplate')->StandardTemplateList(
        Valid => 1,
        Type  => 'Email',
    );

    my $QueueStandardTemplates = $Self->_GetStandardTemplates(
        %Param,
        TicketID => $Self->{TicketID} || '',
    );

    if (
        IsHashRefWithData(
            $QueueStandardTemplates
                || ( $Param{Queue} && IsHashRefWithData( \%StandardTemplates ) )
        )
        )
    {
        $Param{StandardTemplateStrg} = $LayoutObject->BuildSelection(
            Data       => $QueueStandardTemplates    || {},
            Name       => 'StandardTemplateID',
            SelectedID => $Param{StandardTemplateID} || '',
            Class      => 'Modernize',
            PossibleNone => 1,
            Sort         => 'AlphanumericValue',
            Translation  => 1,
            Max          => 200,
        );
        $LayoutObject->Block(
            Name => 'StandardTemplate',
            Data => {%Param},
        );
    }

    # show attachments
    ATTACHMENT:
    for my $Attachment ( @{ $Param{Attachments} } ) {
        if (
            $Attachment->{ContentID}
            && $LayoutObject->{BrowserRichText}
            && ( $Attachment->{ContentType} =~ /image/i )
            )
        {
            next ATTACHMENT;
        }

        $LayoutObject->Block(
            Name => 'Attachment',
            Data => $Attachment,
        );
    }

    # add rich text editor
    if ( $LayoutObject->{BrowserRichText} ) {

        # use height/width defined for this screen
        $Param{RichTextHeight} = $Config->{RichTextHeight} || 0;
        $Param{RichTextWidth}  = $Config->{RichTextWidth}  || 0;

        $LayoutObject->Block(
            Name => 'RichText',
            Data => \%Param,
        );
    }

    # create & return output
    return $LayoutObject->Output(
        TemplateFile => 'AgentTicketEmailOutbound',
        Data         => \%Param
    );
}

sub _GetFieldsToUpdate {
    my ( $Self, %Param ) = @_;

    my @UpdatableFields;

    # set the fields that can be updateable via AJAXUpdate
    if ( !$Param{OnlyDynamicFields} ) {
        @UpdatableFields = qw( ComposeStateID );
    }

    # get config for frontend module
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # cycle through the activated Dynamic Fields for this screen
    DYNAMICFIELD:
    for my $DynamicFieldConfig ( @{$DynamicField} ) {
        next DYNAMICFIELD if !IsHashRefWithData($DynamicFieldConfig);

        my $IsACLReducible = $Kernel::OM->Get('Kernel::System::DynamicField::Backend')->HasBehavior(
            DynamicFieldConfig => $DynamicFieldConfig,
            Behavior           => 'IsACLReducible',
        );
        next DYNAMICFIELD if !$IsACLReducible;

        push @UpdatableFields, 'DynamicField_' . $DynamicFieldConfig->{Name};
    }

    return \@UpdatableFields;
}

sub _GetExtendedParams {
    my ( $Self, %Param ) = @_;

    # get param object
    my $ParamObject = $Kernel::OM->Get('Kernel::System::Web::Request');

    # get params
    my %GetParam;
    for my $Key (
        qw(From To Cc Bcc Subject Body ComposeStateID ArticleTypeID
        ArticleID TimeUnits Year Month Day Hour Minute FormID)
        )
    {
        my $Value = $ParamObject->GetParam( Param => $Key );
        if ( defined $Value ) {
            $GetParam{$Key} = $Value;
        }
    }

    $GetParam{EmailTemplateID} = $ParamObject->GetParam( Param => 'EmailTemplateID' ) || '';

    # create form id
    if ( !$GetParam{FormID} ) {
        $GetParam{FormID} = $Kernel::OM->Get('Kernel::System::Web::UploadCache')->FormIDCreate();
    }

    # hash for check duplicated entries
    my %AddressesList;
    my @MultipleCustomer;
    my $CustomersNumber = $ParamObject->GetParam( Param => 'CustomerTicketCounterToCustomer' ) || 0;
    my $Selected = $ParamObject->GetParam( Param => 'CustomerSelected' ) || '';

    # get check item object
    my $CheckItemObject = $Kernel::OM->Get('Kernel::System::CheckItem');

    if ($CustomersNumber) {
        my $CustomerCounter = 1;
        for my $Count ( 1 ... $CustomersNumber ) {
            my $CustomerElement = $ParamObject->GetParam( Param => 'CustomerTicketText_' . $Count );
            my $CustomerSelected = ( $Selected eq $Count ? 'checked="checked"' : '' );
            my $CustomerKey = $ParamObject->GetParam( Param => 'CustomerKey_' . $Count )
                || '';
            my $CustomerQueue = $ParamObject->GetParam( Param => 'CustomerQueue_' . $Count )
                || '';
            if ($CustomerElement) {

                if ( $GetParam{To} ) {
                    $GetParam{To} .= ', ' . $CustomerElement;
                }
                else {
                    $GetParam{To} = $CustomerElement;
                }

                # check email address
                my $CustomerErrorMsg = 'CustomerGenericServerErrorMsg';
                my $CustomerError    = '';
                for my $Email ( Mail::Address->parse($CustomerElement) ) {
                    if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                        $CustomerErrorMsg = $CheckItemObject->CheckErrorType()
                            . 'ServerErrorMsg';
                        $CustomerError = 'ServerError';
                    }
                }

                # check for duplicated entries
                if ( defined $AddressesList{$CustomerElement} && $CustomerError eq '' ) {
                    $CustomerErrorMsg = 'IsDuplicatedServerErrorMsg';
                    $CustomerError    = 'ServerError';
                }

                my $CustomerDisabled = '';
                my $CountAux         = $CustomerCounter++;
                if ( $CustomerError ne '' ) {
                    $CustomerDisabled = 'disabled="disabled"';
                    $CountAux         = $Count . 'Error';
                }

                if ( $CustomerQueue ne '' ) {
                    $CustomerQueue = $Count;
                }

                push @MultipleCustomer, {
                    Count            => $CountAux,
                    CustomerElement  => $CustomerElement,
                    CustomerSelected => $CustomerSelected,
                    CustomerKey      => $CustomerKey,
                    CustomerError    => $CustomerError,
                    CustomerErrorMsg => $CustomerErrorMsg,
                    CustomerDisabled => $CustomerDisabled,
                    CustomerQueue    => $CustomerQueue,
                };
                $AddressesList{$CustomerElement} = 1;
            }
        }
    }

    my @MultipleCustomerCc;
    my $CustomersNumberCc = $ParamObject->GetParam( Param => 'CustomerTicketCounterCcCustomer' ) || 0;

    if ($CustomersNumberCc) {
        my $CustomerCounterCc = 1;
        for my $Count ( 1 ... $CustomersNumberCc ) {
            my $CustomerElementCc = $ParamObject->GetParam( Param => 'CcCustomerTicketText_' . $Count );
            my $CustomerKeyCc     = $ParamObject->GetParam( Param => 'CcCustomerKey_' . $Count )
                || '';
            my $CustomerQueueCc = $ParamObject->GetParam( Param => 'CcCustomerQueue_' . $Count )
                || '';

            if ($CustomerElementCc) {

                if ( $GetParam{Cc} ) {
                    $GetParam{Cc} .= ', ' . $CustomerElementCc;
                }
                else {
                    $GetParam{Cc} = $CustomerElementCc;
                }

                # check email address
                my $CustomerErrorMsgCc = 'CustomerGenericServerErrorMsg';
                my $CustomerErrorCc    = '';
                for my $Email ( Mail::Address->parse($CustomerElementCc) ) {
                    if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                        $CustomerErrorMsgCc = $CheckItemObject->CheckErrorType()
                            . 'ServerErrorMsg';
                        $CustomerErrorCc = 'ServerError';
                    }
                }

                # check for duplicated entries
                if ( defined $AddressesList{$CustomerElementCc} && $CustomerErrorCc eq '' ) {
                    $CustomerErrorMsgCc = 'IsDuplicatedServerErrorMsg';
                    $CustomerErrorCc    = 'ServerError';
                }

                my $CustomerDisabledCc = '';
                my $CountAuxCc         = $CustomerCounterCc++;
                if ( $CustomerErrorCc ne '' ) {
                    $CustomerDisabledCc = 'disabled="disabled"';
                    $CountAuxCc         = $Count . 'Error';
                }

                if ( $CustomerQueueCc ne '' ) {
                    $CustomerQueueCc = $Count;
                }

                push @MultipleCustomerCc, {
                    Count            => $CountAuxCc,
                    CustomerElement  => $CustomerElementCc,
                    CustomerKey      => $CustomerKeyCc,
                    CustomerError    => $CustomerErrorCc,
                    CustomerErrorMsg => $CustomerErrorMsgCc,
                    CustomerDisabled => $CustomerDisabledCc,
                    CustomerQueue    => $CustomerQueueCc,
                };
                $AddressesList{$CustomerElementCc} = 1;
            }
        }
    }

    my @MultipleCustomerBcc;
    my $CustomersNumberBcc = $ParamObject->GetParam( Param => 'CustomerTicketCounterBccCustomer' ) || 0;

    if ($CustomersNumberBcc) {
        my $CustomerCounterBcc = 1;
        for my $Count ( 1 ... $CustomersNumberBcc ) {
            my $CustomerElementBcc = $ParamObject->GetParam( Param => 'BccCustomerTicketText_' . $Count );
            my $CustomerKeyBcc     = $ParamObject->GetParam( Param => 'BccCustomerKey_' . $Count )
                || '';
            my $CustomerQueueBcc = $ParamObject->GetParam( Param => 'BccCustomerQueue_' . $Count )
                || '';

            if ($CustomerElementBcc) {

                if ( $GetParam{Bcc} ) {
                    $GetParam{Bcc} .= ', ' . $CustomerElementBcc;
                }
                else {
                    $GetParam{Bcc} = $CustomerElementBcc;
                }

                # check email address
                my $CustomerErrorMsgBcc = 'CustomerGenericServerErrorMsg';
                my $CustomerErrorBcc    = '';
                for my $Email ( Mail::Address->parse($CustomerElementBcc) ) {
                    if ( !$CheckItemObject->CheckEmail( Address => $Email->address() ) ) {
                        $CustomerErrorMsgBcc = $CheckItemObject->CheckErrorType()
                            . 'ServerErrorMsg';
                        $CustomerErrorBcc = 'ServerError';
                    }
                }

                # check for duplicated entries
                if ( defined $AddressesList{$CustomerElementBcc} && $CustomerErrorBcc eq '' ) {
                    $CustomerErrorMsgBcc = 'IsDuplicatedServerErrorMsg';
                    $CustomerErrorBcc    = 'ServerError';
                }

                my $CustomerDisabledBcc = '';
                my $CountAuxBcc         = $CustomerCounterBcc++;
                if ( $CustomerErrorBcc ne '' ) {
                    $CustomerDisabledBcc = 'disabled="disabled"';
                    $CountAuxBcc         = $Count . 'Error';
                }

                if ( $CustomerQueueBcc ne '' ) {
                    $CustomerQueueBcc = $Count;
                }

                push @MultipleCustomerBcc, {
                    Count            => $CountAuxBcc,
                    CustomerElement  => $CustomerElementBcc,
                    CustomerKey      => $CustomerKeyBcc,
                    CustomerError    => $CustomerErrorBcc,
                    CustomerErrorMsg => $CustomerErrorMsgBcc,
                    CustomerDisabled => $CustomerDisabledBcc,
                    CustomerQueue    => $CustomerQueueBcc,
                };
                $AddressesList{$CustomerElementBcc} = 1;
            }
        }
    }

    return (
        GetParam            => \%GetParam,
        MultipleCustomer    => \@MultipleCustomer,
        MultipleCustomerCc  => \@MultipleCustomerCc,
        MultipleCustomerBcc => \@MultipleCustomerBcc,
    );
}

sub _GetStandardTemplates {
    my ( $Self, %Param ) = @_;

    # get create templates
    my %Templates;

    # check needed
    return \%Templates if !$Param{QueueID} && !$Param{TicketID};

    my $QueueID = $Param{QueueID} || '';
    if ( !$Param{QueueID} && $Param{TicketID} ) {

        # get QueueID from the ticket
        my %Ticket = $Kernel::OM->Get('Kernel::System::Ticket')->TicketGet(
            TicketID      => $Param{TicketID},
            DynamicFields => 0,
            UserID        => $Self->{UserID},
        );
        $QueueID = $Ticket{QueueID} || '';
    }

    # fetch all std. templates
    my %StandardTemplates = $Kernel::OM->Get('Kernel::System::Queue')->QueueStandardTemplateMemberList(
        QueueID       => $QueueID,
        TemplateTypes => 1,
    );

    # return empty hash if there are no templates for this screen
    return \%Templates if !IsHashRefWithData( $StandardTemplates{Email} );

    # return just the templates for this screen
    return $StandardTemplates{Email};
}

# KIX4OTRS-capeIT
sub _GetShownDynamicFields {
    my ( $Self, %Param ) = @_;

    # use only dynamic fields which passed the acl
    my %TicketAclFormData = $Kernel::OM->Get('Kernel::System::Ticket')->TicketAclFormData();

    # get config of frontend module
    my $Config = $Kernel::OM->Get('Kernel::Config')->Get("Ticket::Frontend::$Self->{Action}");

    # get the dynamic fields for this screen
    my $DynamicField = $Kernel::OM->Get('Kernel::System::DynamicField')->DynamicFieldListGet(
        Valid       => 1,
        ObjectType  => [ 'Ticket', 'Article' ],
        FieldFilter => $Config->{DynamicField} || {},
    );

    # cycle through dynamic fields to get shown or hidden fields
    for my $DynamicField ( @{$DynamicField} ) {

        # if field was not configured initially set it as not visible
        if ( $Self->{NotShownDynamicFields}->{ $DynamicField->{Name} } ) {
            $DynamicField->{Shown} = 0;
        }
        else {

            # hide DynamicFields only if we have ACL's
            if (
                IsHashRefWithData( \%TicketAclFormData )
                && defined $TicketAclFormData{ $DynamicField->{Name} }
                )
            {
                if ( $TicketAclFormData{ $DynamicField->{Name} } >= 1 ) {
                    $DynamicField->{Shown} = 1;
                }
                else {
                    $DynamicField->{Shown} = 0;
                }
            }

            # else show them by default
            else {
                $DynamicField->{Shown} = 1;
            }
        }
    }

    return 1;
}

# EO KIX4OTRS-capeIT

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
