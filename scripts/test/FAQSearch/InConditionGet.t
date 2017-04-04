# --
# Modified version of the work: Copyright (C) 2006-2017 c.a.p.e. IT GmbH, http://www.cape-it.de
# based on the original work of:
# Copyright (C) 2001-2017 OTRS AG, http://otrs.com/
# --
# This software comes with ABSOLUTELY NO WARRANTY. For details, see
# the enclosed file COPYING for license information (AGPL). If you
# did not receive this file, see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;
use utf8;

use vars (qw($Self));

# get helper object
$Kernel::OM->ObjectParamAdd(
    'Kernel::System::UnitTest::Helper' => {
        RestoreDatabase => 1,
    },
);
my $Helper = $Kernel::OM->Get('Kernel::System::UnitTest::Helper');

my @Tests = (
    {
        Name   => 'No array',
        Params => {
            TableColumn => 'test.table',
            IDRef       => 1,
        },
        Result => undef,
    },
    {
        Name   => 'Single Integer',
        Params => {
            TableColumn => 'test.table',
            IDRef       => [1],
        },
        Result => ' (  test.table IN (1)  ) ',
    },
    {
        Name   => 'Sorted values',
        Params => {
            TableColumn => 'test.table',
            IDRef       => [ 2, 1, -1, 0 ],
        },
        Result => ' (  test.table IN (-1, 0, 1, 2)  ) ',
    },
    {
        Name   => 'Invalid value',
        Params => {
            TableColumn => 'test.table',
            IDRef       => [1.1],
        },
        Result => undef,
    },
    {
        Name   => 'Mix of valid and invalid values',
        Params => {
            TableColumn => 'test.table',
            IDRef       => [ 1, 1.1 ],
        },
        Result => undef,
    },
);

# get FAQ object
my $FAQObject = $Kernel::OM->Get('Kernel::System::FAQ');

for my $Test (@Tests) {
    $Self->Is(
        scalar $FAQObject->_InConditionGet( %{ $Test->{Params} } ),
        $Test->{Result},
        "$Test->{Name} _InConditionGet()"
    );
}

# cleanup is done by RestoreDatabase.

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
