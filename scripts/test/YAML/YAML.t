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

# get YAML object
my $YAMLObject = $Kernel::OM->Get('Kernel::System::YAML');

my @Tests = (
    {
        Name          => 'Simple string',
        Data          => 'Teststring <tag> äß@ø " \\" \' \'\'',
        SuccessDecode => 1,
    },
    {
        Name => 'Complex data',
        Data => {
            Key   => 'Teststring <tag> äß@ø " \\" \' \'\'',
            Value => [
                {
                    Subkey  => 'Value',
                    Subkey2 => undef,
                },
                1234,
                0,
                undef,
                'Teststring <tag> äß@ø " \\" \' \'\'',
            ],
        },
        SuccessDecode => 1,
    },
    {
        Name          => 'Special YAML chars',
        Data          => ' a " a " a \'\' a \'\' a',
        SuccessDecode => 1,
    },
    {
        Name          => 'UTF8 string',
        Data          => 'kéy',
        SuccessDecode => 1,
    },
    {
        Name          => 'UTF8 string, loader',
        Data          => 'kéy',
        YAMLString    => '--- kéy' . "\n",
        SuccessDecode => 1,
    },
    {
        Name          => 'UTF8 string without UTF8-Flag',
        Data          => 'k\x{e9}y',
        SuccessDecode => 1,
    },
    {
        Name          => 'UTF8 string without UTF8-Flag, loader',
        Data          => 'k\x{e9}y',
        YAMLString    => '--- k\x{e9}y' . "\n",
        SuccessDecode => 1,
    },
    {
        Name          => 'Very long string',      # see https://bugzilla.redhat.com/show_bug.cgi?id=192400
        Data          => ' äø<>"\'' x 40_000,
        SkipEngine    => 'YAML',                  # This test does not run with plain YAML, see the bug above
        SuccessDecode => 1,
    },
    {
        Name => 'Wrong newline',
        Data => {
            DefaultValue   => '',
            PossibleValues => undef,
        },
        YAMLString    => "---\rDefaultValue: ''\rPossibleValues: ~\r",
        SuccessDecode => 1,
    },
    {
        Name => 'Windows newline',
        Data => {
            DefaultValue   => '',
            PossibleValues => undef,
        },
        YAMLString    => "---\r\nDefaultValue: ''\r\nPossibleValues: ~\r\n",
        SuccessDecode => 1,
    },
    {
        Name => 'Unix newline',
        Data => {
            DefaultValue   => '',
            PossibleValues => undef,
        },
        YAMLString    => "---\nDefaultValue: ''\nPossibleValues: ~\n",
        SuccessDecode => 1,
    },
    {
        Name          => 'Invalid YAML string',
        Data          => '1',
        YAMLString    => "-\nDefaultValue: ''\nPossibleValues: ~\n",
        SuccessDecode => 0,
    },

 # Test case to reproduce a bug with YAML that is generated by the pure-perl YAML module.
 # See also http://blogs.perl.org/users/brian_d_foy/2010/06/block-sequence-entries-are-not-allowed-in-this-context.html.
    {
        Name => 'Missing quotes',
        Data => {
            PossibleValues => '-',
        },
        YAMLString    => "---\nPossibleValues: -\n",
        SuccessDecode => 1,
    },

    # This is how the previous example should look like
    {
        Name => 'Missing quotes (fixed)',
        Data => {
            PossibleValues => '-',
        },
        YAMLString    => "---\nPossibleValues: '-'\n",
        SuccessDecode => 1,
    },
);

ENGINE:
for my $Engine (qw(YAML::XS YAML)) {

    # locally override the internal engine of YAML::Any to force testing
    local @YAML::Any::_TEST_ORDER = ($Engine);    ## no critic

    TEST:
    for my $Test (@Tests) {

        next TEST if defined $Test->{SkipEngine} && $Engine eq $Test->{SkipEngine};

        my $YAMLString = $Test->{YAMLString} || $YAMLObject->Dump( Data => $Test->{Data} );
        my $YAMLData = $YAMLObject->Load( Data => $YAMLString );

        if ( $Test->{SuccessDecode} ) {
            $Self->IsDeeply(
                $YAMLData,
                $Test->{Data},
                "Engine $Engine - $Test->{Name}",
            );
        }
        else {
            $Self->False(
                $YAMLData,
                "Engine $Engine - $Test->{Name}",
            );
        }
    }
}

1;

=back

=head1 TERMS AND CONDITIONS

This software is part of the KIX project
(L<http://www.kixdesk.com/>).

This software comes with ABSOLUTELY NO WARRANTY. For details, see the enclosed file
COPYING for license information (AGPL). If you did not receive this file, see

<http://www.gnu.org/licenses/agpl.txt>.

=cut
