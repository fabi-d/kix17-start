# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get environment object
my $EnvironmentObject = $Kernel::OM->Get('Kernel::System::Environment');

my %OSInfo = $EnvironmentObject->OSInfoGet();

for my $Attribute (qw(Hostname OS OSName User)) {
    $Self->True(
        $OSInfo{$Attribute},
        "OSInfoGet - returned $Attribute",
    );
}

$Self->True(
    $OSInfo{OSName} !~ m{\A Unknown }xms,
    "OSInfoGet - OSName is not unknown but '$OSInfo{OSName}'",
);

my %PerlInfo = $EnvironmentObject->PerlInfoGet();

$Self->True(
    $PerlInfo{PerlVersion} =~ /^\d.\d\d.\d/,
    "PerlInfoGet - retrieved Perl version.",
);

$Self->False(
    $PerlInfo{Modules},
    "PerlInfoGet - no module versions if not specified.",
);

%PerlInfo = $EnvironmentObject->PerlInfoGet(
    BundledModules => 1,
);

$Self->True(
    $PerlInfo{PerlVersion} =~ /^\d.\d\d.\d/,
    "PerlInfoGet w/ BundledModules - retrieved Perl version.",
);

$Self->True(
    $PerlInfo{Modules}{CGI} =~ /^\d.\d\d$/,
    "PerlInfoGet w/ BundledModules - found version for CGI $PerlInfo{Modules}->{CGI}",
);

$Self->True(
    $PerlInfo{Modules}->{'JSON::PP'} =~ /^\d.\d\d/,
    "PerlInfoGet w/ BundledModules - found version for JSON::PP $PerlInfo{Modules}->{'JSON::PP'}",
);

my $Version = $EnvironmentObject->ModuleVersionGet(
    Module => 'MIME::Parser',
);

$Self->True(
    $Version =~ /^\d\.\d\d\d$/,
    "ModuleVersionGet - Version for MIME::Parser is $Version.",
);

$Version = $EnvironmentObject->ModuleVersionGet(
    Module => 'SCHMIME::Parser',
);

$Self->False(
    $Version,
    "ModuleVersionGet - Version for SCMIME::Parser does not exist.",
);

my %DBInfo = $EnvironmentObject->DBInfoGet();

for my $Key (qw(Database Host Type User Version)) {
    $Self->True(
        $DBInfo{$Key} =~ /\w\w/,
        "DBInfoGet - returned value for $Key",
    );
}

#rbo - T2016121190001552 - renamed OTRS to KIX
my %KIXInfo = $EnvironmentObject->KIXInfoGet();

for my $Key (qw(Version Home Host Product SystemID DefaultLanguage)) {
    $Self->True(
        $KIXInfo{$Key},
        "KIXInfoGet - returned value for $Key",
    );
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<https://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
LICENSE for license information (AGPL). If you did not receive this file, see

<https://www.gnu.org/licenses/agpl.txt>.

=cut
