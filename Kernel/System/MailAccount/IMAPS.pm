# --
# Modified version of the work: Copyright (C) 2006-2019 c.a.p.e. IT GmbH, https://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2019 OTRS AG, https://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file LICENSE for license information (AGPL). If you
# did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
# --

package Kernel::System::MailAccount::IMAPS;

use strict;
use warnings;

use IO::Socket::SSL;

use base qw(Kernel::System::MailAccount::IMAP);

our @ObjectDependencies = (
    'Kernel::System::Log',
);

sub Connect {
    my ( $Self, %Param ) = @_;

    # check needed stuff
    for (qw(Login Password Host Timeout Debug)) {
        if ( !defined $Param{$_} ) {
            $Kernel::OM->Get('Kernel::System::Log')->Log(
                Priority => 'error',
                Message  => "Need $_!"
            );
            return;
        }
    }

    my $Type = 'IMAPS';

    # connect to host
    my $IMAPObject = Net::IMAP::Simple->new(
        $Param{Host},
        timeout     => $Param{Timeout},
        debug       => $Param{Debug},
        use_ssl     => 1,
        ssl_options => [
            SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE(),
        ],
    );
    if ( !$IMAPObject ) {
        return (
            Successful => 0,
            Message    => "$Type: Can't connect to $Param{Host}"
        );
    }

    # authentication
    my $Auth = $IMAPObject->login( $Param{Login}, $Param{Password} );
    if ( !defined $Auth ) {
        $IMAPObject->quit();
        return (
            Successful => 0,
            Message    => "$Type: Auth for user $Param{Login}/$Param{Host} failed!"
        );
    }

    return (
        Successful => 1,
        IMAPObject => $IMAPObject,
        Type       => $Type,
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
