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

use Kernel::System::VariableCheck qw(:all);

# get needed objects
my $ConfigObject = $Kernel::OM->Get('Kernel::Config');

# standard variables
my $ExpectedTestResults = {};
my $TestVariables       = {};

my $RunTests = sub {
    my ( $FunctionName, $Variables, $ExpectedResults ) = @_;

    for my $VariableKey ( sort keys %{$Variables} ) {

        # variable names defined for this function should return 1
        if ( $ExpectedResults->{$VariableKey} ) {
            $Self->True(
                ( \&$FunctionName )->( $Variables->{$VariableKey} ) || 0,
                "VariableCheck $FunctionName True ($VariableKey)",
            );
        }

        # variable names not defined for this function should return undef
        else {
            $Self->False(
                ( \&$FunctionName )->( $Variables->{$VariableKey} ) || 0,
                "VariableCheck $FunctionName False ($VariableKey)",
            );
        }
    }

    # all functions should only accept a single param
    $Self->False(
        ( \&$FunctionName )->( undef, undef ) || 0,
        "VariableCheck $FunctionName False (Array)",
    );

    return;
};

# test variables for all types
my @CommonVariables = (
    ArrayRef      => [0],
    ArrayRefEmpty => [],
    HashRef       => { 0 => 0 },
    HashRefEmpty  => {},
    ObjectRef     => $ConfigObject,
    RefRef        => \\0,
    ScalarRef     => \0,
    String        => 0,
    StringEmpty   => '',
    Undef         => undef,
);

# test variables for numerical checks
my @NumberVariables = (
    Number1  => 1,
    Number2  => 99,
    Number3  => -987654321,
    Number4  => '.00000001',
    Number5  => '-.9999999',
    Number6  => '9.999e+99',
    Number7  => '-9.999e+99',
    Number8  => '1.111e-99',
    Number9  => '-9.999e-99',
    Number10 => '1.e1',
    Number11 => '1.E2',
    Number12 => 'a.E2',
    Number13 => '1.E2.2',
    Number14 => '1.-e1',
    Number15 => '1€+1',
);

# test variables for ipv6 tests
my @IPv6Variables = (
    IPv6001 => '::',
    IPv6002 => '0:0:0:0:0:0:0:0',
    IPv6003 => '0000:0000:0000:0000:0000:0000:0000:0000',
    IPv6004 => '0000:0000:0000:0000:0000:0000:0000:0001',
    IPv6005 => '0:0:0:0:0:0:0:1',
    IPv6006 => '0:0:0:0:0:0:13.1.68.3',
    IPv6007 => '0:0:0:0:0:FFFF:129.144.52.38',
    IPv6008 => '::0:a:b:c:d:e:f',
    IPv6009 => '0:a:b:c:d:e:f::',
    IPv6010 => '1::',
    IPv6011 => '::1',
    IPv6012 => '1111::',
    IPv6013 => '1111::123.123.123.123',
    IPv6014 => '1111:2222::',
    IPv6015 => '1111:2222::123.123.123.123',
    IPv6016 => '1111:2222:3333::',
    IPv6017 => '1111:2222:3333::123.123.123.123',
    IPv6018 => '1111:2222:3333:4444::',
    IPv6019 => '1111:2222:3333:4444::123.123.123.123',
    IPv6020 => '1111:2222:3333:4444:5555::',
    IPv6021 => '1111:2222:3333:4444:5555::123.123.123.123',
    IPv6022 => '1111:2222:3333:4444:5555:6666::',
    IPv6023 => '1111:2222:3333:4444:5555:6666:123.123.123.123',
    IPv6024 => '1111:2222:3333:4444:5555:6666:7777::',
    IPv6025 => '1111:2222:3333:4444:5555:6666:7777:8888',
    IPv6026 => '1111:2222:3333:4444:5555:6666::8888',
    IPv6027 => '1111:2222:3333:4444:5555::7777:8888',
    IPv6028 => '1111:2222:3333:4444:5555::8888',
    IPv6029 => '1111:2222:3333:4444::6666:123.123.123.123',
    IPv6030 => '1111:2222:3333:4444::6666:7777:8888',
    IPv6031 => '1111:2222:3333:4444::7777:8888',
    IPv6032 => '1111:2222:3333:4444::8888',
    IPv6033 => '1111:2222:3333::5555:6666:123.123.123.123',
    IPv6034 => '1111:2222:3333::5555:6666:7777:8888',
    IPv6035 => '1111:2222:3333::6666:123.123.123.123',
    IPv6036 => '1111:2222:3333::6666:7777:8888',
    IPv6037 => '1111:2222:3333::7777:8888',
    IPv6038 => '1111:2222:3333::8888',
    IPv6039 => '1111:2222::4444:5555:6666:123.123.123.123',
    IPv6040 => '1111:2222::4444:5555:6666:7777:8888',
    IPv6041 => '1111:2222::5555:6666:123.123.123.123',
    IPv6042 => '1111:2222::5555:6666:7777:8888',
    IPv6043 => '1111:2222::6666:123.123.123.123',
    IPv6044 => '1111:2222::6666:7777:8888',
    IPv6045 => '1111:2222::7777:8888',
    IPv6046 => '1111:2222::8888',
    IPv6047 => '1111::3333:4444:5555:6666:123.123.123.123',
    IPv6048 => '1111::3333:4444:5555:6666:7777:8888',
    IPv6049 => '1111::4444:5555:6666:123.123.123.123',
    IPv6050 => '1111::4444:5555:6666:7777:8888',
    IPv6051 => '1111::5555:6666:123.123.123.123',
    IPv6052 => '1111::5555:6666:7777:8888',
    IPv6053 => '1111::6666:123.123.123.123',
    IPv6054 => '1111::6666:7777:8888',
    IPv6055 => '1111::7777:8888',
    IPv6056 => '1111::8888',
    IPv6057 => '1::1.2.3.4',
    IPv6058 => '1:2::',
    IPv6059 => '1:2::1.2.3.4',
    IPv6060 => '1:2:3::',
    IPv6061 => '1::2:3',
    IPv6062 => '::123.123.123.123',
    IPv6063 => '1:2:3::1.2.3.4',
    IPv6064 => '1:2:3:4::',
    IPv6065 => '1::2:3:4',
    IPv6066 => '1:2:3:4::1.2.3.4',
    IPv6067 => '1:2:3:4:5::',
    IPv6068 => '1::2:3:4:5',
    IPv6069 => '1:2:3:4:5::1.2.3.4',
    IPv6070 => '1:2:3:4::5:1.2.3.4',
    IPv6071 => '1:2:3:4:5:6::',
    IPv6072 => '1::2:3:4:5:6',
    IPv6073 => '1:2:3:4:5:6:1.2.3.4',
    IPv6074 => '1::2:3:4:5:6:7',
    IPv6075 => '1:2:3:4:5:6:7:8',
    IPv6076 => '1:2:3:4:5:6::8',
    IPv6077 => '1:2:3:4:5::7:8',
    IPv6078 => '1:2:3:4:5::8',
    IPv6079 => '1:2:3:4::7:8',
    IPv6080 => '1:2:3:4::8',
    IPv6081 => '1:2:3::5:1.2.3.4',
    IPv6082 => '1:2:3::7:8',
    IPv6083 => '1:2:3::8',
    IPv6084 => '1:2::5:1.2.3.4',
    IPv6085 => '1:2::7:8',
    IPv6086 => '1:2::8',
    IPv6087 => '::13.1.68.3',
    IPv6088 => '1::5:11.22.33.44',
    IPv6089 => '1::5:1.2.3.4',
    IPv6090 => '1::7:8',
    IPv6091 => '1::8',
    IPv6092 => '2001:0000:1234:0000:0000:C1C0:ABCD:0876',
    IPv6093 => '2001:0db8:0000:0000:0000:0000:1428:57ab',
    IPv6094 => '2001:0db8:0000:0000:0000::1428:57ab',
    IPv6095 => '2001:0db8:0:0:0:0:1428:57ab',
    IPv6096 => '2001:0db8:0:0::1428:57ab',
    IPv6097 => '2001:0db8:1234::',
    IPv6098 => '2001:0db8:1234:0000:0000:0000:0000:0000',
    IPv6099 => '2001:0db8:1234:ffff:ffff:ffff:ffff:ffff',
    IPv6100 => '2001:0db8::1428:57ab',
    IPv6101 => '2001:0db8:85a3:0000:0000:8a2e:0370:7334',
    IPv6102 => '2001:db8::',
    IPv6103 => '2001:DB8:0:0:8:800:200C:417A',
    IPv6104 => '2001:db8::1428:57ab',
    IPv6105 => '2001:db8:85a3:0:0:8a2e:370:7334',
    IPv6106 => '2001:db8:85a3::8a2e:370:7334',
    IPv6107 => '2001:DB8::8:800:200C:417A',
    IPv6108 => '2001:db8:a::123',
    IPv6109 => '2002::',
    IPv6110 => '2::10',
    IPv6111 => '::2222:3333:4444:5555:6666:123.123.123.123',
    IPv6112 => '::2222:3333:4444:5555:6666:7777:8888',
    IPv6113 => '::2:3',
    IPv6114 => '::2:3:4',
    IPv6115 => '::2:3:4:5',
    IPv6116 => '::2:3:4:5:6',
    IPv6117 => '::2:3:4:5:6:7',
    IPv6118 => '::2:3:4:5:6:7:8',
    IPv6119 => '::3333:4444:5555:6666:7777:8888',
    IPv6120 => '3ffe:0b00:0000:0000:0001:0000:0000:000a',
    IPv6121 => '::4444:5555:6666:123.123.123.123',
    IPv6122 => '::4444:5555:6666:7777:8888',
    IPv6123 => '::5555:6666:123.123.123.123',
    IPv6124 => '::5555:6666:7777:8888',
    IPv6125 => '::6666:123.123.123.123',
    IPv6126 => '::6666:7777:8888',
    IPv6127 => '::7777:8888',
    IPv6128 => '::8',
    IPv6129 => '::8888',
    IPv6130 => 'a:b:c:d:e:f:0::',
    IPv6131 => 'fe80::',
    IPv6132 => 'fe80:0000:0000:0000:0204:61ff:fe9d:f156',
    IPv6133 => 'fe80:0:0:0:204:61ff:254.157.241.86',
    IPv6134 => 'fe80:0:0:0:204:61ff:fe9d:f156',
    IPv6135 => 'fe80::1',
    IPv6136 => 'fe80::204:61ff:254.157.241.86',
    IPv6137 => 'fe80::204:61ff:fe9d:f156',
    IPv6138 => 'fe80::217:f2ff:254.7.237.98',
    IPv6139 => 'fe80::217:f2ff:fe07:ed62',
    IPv6140 => 'FF01:0:0:0:0:0:0:101',
    IPv6141 => 'FF01::101',
    IPv6142 => 'FF02:0000:0000:0000:0000:0000:0000:0001',
    IPv6143 => 'ff02::1',
    IPv6144 => '::ffff:0:0',
    IPv6145 => '::ffff:0c22:384e',
    IPv6146 => '::ffff:12.34.56.78',
    IPv6147 => '::FFFF:129.144.52.38',
    IPv6148 => '::ffff:192.0.2.128',
    IPv6149 => '::ffff:192.168.1.1',
    IPv6150 => '::ffff:192.168.1.26',
    IPv6151 => '::ffff:c000:280',
    IPv6152 => ':',
    IPv6153 => ':::',
    IPv6154 => '::.',
    IPv6155 => '::..',
    IPv6156 => '::...',
    IPv6157 => '02001:0000:1234:0000:0000:C1C0:ABCD:0876',
    IPv6158 => '::1...',
    IPv6159 => '\':10.0.0.1',
    IPv6160 => ':1111::',
    IPv6161 => '1111',
    IPv6162 => '1111:',
    IPv6163 => '1111:::',
    IPv6164 => ':1111::1.2.3.4',
    IPv6165 => '1111:1.2.3.4',
    IPv6166 => ':1111:2222::',
    IPv6167 => '1111:2222',
    IPv6168 => '1111:2222:',
    IPv6169 => '1111:2222:::',
    IPv6170 => ':1111:2222::1.2.3.4',
    IPv6171 => '1111:2222:1.2.3.4',
    IPv6172 => ':1111:2222:3333::',
    IPv6173 => '1111:2222:3333',
    IPv6174 => '1111:2222:3333:',
    IPv6175 => '1111:2222:3333:::',
    IPv6176 => ':1111:2222:3333::1.2.3.4',
    IPv6177 => '1111:2222:3333:1.2.3.4',
    IPv6178 => ':1111:2222:3333:4444::',
    IPv6179 => '1111:2222:3333:4444',
    IPv6180 => '1111:2222:3333:4444:',
    IPv6181 => '1111:2222:3333:4444:::',
    IPv6182 => ':1111:2222:3333:4444::1.2.3.4',
    IPv6183 => '1111:2222:3333:4444:1.2.3.4',
    IPv6184 => ':1111:2222:3333:4444:5555::',
    IPv6185 => ':1111:2222:3333:4444::5555',
    IPv6186 => '1111:2222:3333:4444:5555',
    IPv6187 => '1111:2222:3333:4444:5555:',
    IPv6188 => '1111:2222:3333:4444:5555:::',
    IPv6189 => '1111:2222:3333:4444::5555:',
    IPv6190 => ':1111:2222:3333:4444:5555::1.2.3.4',
    IPv6191 => '1111:2222:3333:4444:5555:1.2.3.4',
    IPv6192 => '1111:2222:3333:4444:5555:::1.2.3.4',
    IPv6193 => ':1111:2222:3333:4444:5555:6666::',
    IPv6194 => '::1111:2222:3333:4444:5555:6666::',
    IPv6195 => '1111:2222:3333:4444:5555:6666',
    IPv6196 => '1111:2222:3333:4444:5555:6666:',
    IPv6197 => '1111:2222:3333:4444:5555:6666:::',
    IPv6198 => '1111:2222:3333:4444:5555:6666:00.00.00.00',
    IPv6199 => '1111:2222:3333:4444:5555:6666:000.000.000.000',
    IPv6200 => ':1111:2222:3333:4444:5555:6666:1.2.3.4',
    IPv6201 => '1111:2222:3333:4444:5555:6666::1.2.3.4',
    IPv6202 => '1111:2222:3333:4444:5555:66661.2.3.4',
    IPv6203 => '1111:2222:3333:4444:55556666:1.2.3.4',
    IPv6204 => '1111:2222:3333:44445555:6666:1.2.3.4',
    IPv6205 => '1111:2222:33334444:5555:6666:1.2.3.4',
    IPv6206 => '1111:22223333:4444:5555:6666:1.2.3.4',
    IPv6207 => '11112222:3333:4444:5555:6666:1.2.3.4',
    IPv6208 => '1111:2222:3333:4444:5555:6666:1.2.3.4.5',
    IPv6209 => '1111:2222:3333:4444:5555:6666:255.255.255255',
    IPv6210 => '1111:2222:3333:4444:5555:6666:255.255255.255',
    IPv6211 => '1111:2222:3333:4444:5555:6666:255255.255.255',
    IPv6212 => '1111:2222:3333:4444:5555:6666:256.256.256.256',
    IPv6213 => ':1111:2222:3333:4444:5555:6666:7777::',
    IPv6214 => '1111:2222:3333:4444:5555:6666:7777',
    IPv6215 => '1111:2222:3333:4444:5555:6666:7777:',
    IPv6216 => '1111:2222:3333:4444:5555:6666:7777:::',
    IPv6217 => '1111:2222:3333:4444:5555:6666:7777:1.2.3.4',
    IPv6218 => ':1111:2222:3333:4444:5555:6666:7777:8888',
    IPv6219 => '1111:2222:3333:4444:5555:6666:7777:8888:',
    IPv6220 => '1111:2222:3333:4444:5555:6666:7777:8888::',
    IPv6221 => '1111:2222:3333:4444:5555:6666:77778888',
    IPv6222 => '1111:2222:3333:4444:5555:66667777:8888',
    IPv6223 => '1111:2222:3333:4444:55556666:7777:8888',
    IPv6224 => '1111:2222:3333:44445555:6666:7777:8888',
    IPv6225 => '1111:2222:33334444:5555:6666:7777:8888',
    IPv6226 => '1111:22223333:4444:5555:6666:7777:8888',
    IPv6227 => '11112222:3333:4444:5555:6666:7777:8888',
    IPv6228 => '1111:2222:3333:4444:5555:6666:7777:8888:1.2.3.4',
    IPv6229 => '1111:2222:3333:4444:5555:6666:7777:8888:9999',
    IPv6230 => ':1111:2222:3333:4444:5555:6666::8888',
    IPv6231 => '1111:2222:3333:4444:5555:6666::8888:',
    IPv6232 => '1111:2222:3333:4444:5555:6666:::8888',
    IPv6233 => '1111:2222:3333:4444:5555::7777::',
    IPv6234 => ':1111:2222:3333:4444:5555::7777:8888',
    IPv6235 => '1111:2222:3333:4444:5555::7777:8888:',
    IPv6236 => '1111:2222:3333:4444:5555:::7777:8888',
    IPv6237 => ':1111:2222:3333:4444:5555::8888',
    IPv6238 => '1111:2222:3333:4444:5555::8888:',
    IPv6239 => ':1111:2222:3333:4444::6666:1.2.3.4',
    IPv6240 => '1111:2222:3333:4444:::6666:1.2.3.4',
    IPv6241 => '1111:2222:3333:4444::6666:7777::',
    IPv6242 => ':1111:2222:3333:4444::6666:7777:8888',
    IPv6243 => '1111:2222:3333:4444::6666:7777:8888:',
    IPv6244 => '1111:2222:3333:4444:::6666:7777:8888',
    IPv6245 => '1111:2222:3333:4444::6666::8888',
    IPv6246 => ':1111:2222:3333:4444::7777:8888',
    IPv6247 => '1111:2222:3333:4444::7777:8888:',
    IPv6248 => ':1111:2222:3333:4444::8888',
    IPv6249 => '1111:2222:3333:4444::8888:',
    IPv6250 => ':1111:2222:3333::5555',
    IPv6251 => '1111:2222:3333::5555:',
    IPv6252 => '1111:2222:3333::5555::1.2.3.4',
    IPv6253 => ':1111:2222:3333::5555:6666:1.2.3.4',
    IPv6254 => '1111:2222:3333:::5555:6666:1.2.3.4',
    IPv6255 => '1111:2222:3333::5555:6666:7777::',
    IPv6256 => ':1111:2222:3333::5555:6666:7777:8888',
    IPv6257 => '1111:2222:3333::5555:6666:7777:8888:',
    IPv6258 => '1111:2222:3333:::5555:6666:7777:8888',
    IPv6259 => '1111:2222:3333::5555:6666::8888',
    IPv6260 => '1111:2222:3333::5555::7777:8888',
    IPv6261 => ':1111:2222:3333::6666:1.2.3.4',
    IPv6262 => ':1111:2222:3333::6666:7777:8888',
    IPv6263 => '1111:2222:3333::6666:7777:8888:',
    IPv6264 => ':1111:2222:3333::7777:8888',
    IPv6265 => '1111:2222:3333::7777:8888:',
    IPv6266 => ':1111:2222:3333::8888',
    IPv6267 => '1111:2222:3333::8888:',
    IPv6268 => '1111:2222::4444:5555::1.2.3.4',
    IPv6269 => ':1111:2222::4444:5555:6666:1.2.3.4',
    IPv6270 => '1111:2222:::4444:5555:6666:1.2.3.4',
    IPv6271 => '1111:2222::4444:5555:6666:7777::',
    IPv6272 => ':1111:2222::4444:5555:6666:7777:8888',
    IPv6273 => '1111:2222::4444:5555:6666:7777:8888:',
    IPv6274 => '1111:2222:::4444:5555:6666:7777:8888',
    IPv6275 => '1111:2222::4444:5555:6666::8888',
    IPv6276 => '1111:2222::4444:5555::7777:8888',
    IPv6277 => '1111:2222::4444::6666:1.2.3.4',
    IPv6278 => '1111:2222::4444::6666:7777:8888',
    IPv6279 => ':1111:2222::5555',
    IPv6280 => '1111:2222::5555:',
    IPv6281 => ':1111:2222::5555:6666:1.2.3.4',
    IPv6282 => ':1111:2222::5555:6666:7777:8888',
    IPv6283 => '1111:2222::5555:6666:7777:8888:',
    IPv6284 => ':1111:2222::6666:1.2.3.4',
    IPv6285 => ':1111:2222::6666:7777:8888',
    IPv6286 => '1111:2222::6666:7777:8888:',
    IPv6287 => ':1111:2222::7777:8888',
    IPv6288 => '1111:2222::7777:8888:',
    IPv6289 => ':1111:2222::8888',
    IPv6290 => '1111:2222::8888:',
    IPv6291 => '1111::3333:4444:5555::1.2.3.4',
    IPv6292 => ':1111::3333:4444:5555:6666:1.2.3.4',
    IPv6293 => '1111:::3333:4444:5555:6666:1.2.3.4',
    IPv6294 => '1111::3333:4444:5555:6666:7777::',
    IPv6295 => ':1111::3333:4444:5555:6666:7777:8888',
    IPv6296 => '1111::3333:4444:5555:6666:7777:8888:',
    IPv6297 => '1111:::3333:4444:5555:6666:7777:8888',
    IPv6298 => '1111::3333:4444:5555:6666::8888',
    IPv6299 => '1111::3333:4444:5555::7777:8888',
    IPv6300 => '1111::3333:4444::6666:1.2.3.4',
    IPv6301 => '1111::3333:4444::6666:7777:8888',
    IPv6302 => '1111::3333::5555:6666:1.2.3.4',
    IPv6303 => '1111::3333::5555:6666:7777:8888',
    IPv6304 => ':1111::4444:5555:6666:1.2.3.4',
    IPv6305 => ':1111::4444:5555:6666:7777:8888',
    IPv6306 => '1111::4444:5555:6666:7777:8888:',
    IPv6307 => ':1111::5555',
    IPv6308 => '1111::5555:',
    IPv6309 => ':1111::5555:6666:1.2.3.4',
    IPv6310 => ':1111::5555:6666:7777:8888',
    IPv6311 => '1111::5555:6666:7777:8888:',
    IPv6312 => ':1111::6666:1.2.3.4',
    IPv6313 => ':1111::6666:7777:8888',
    IPv6314 => '1111::6666:7777:8888:',
    IPv6315 => ':1111::7777:8888',
    IPv6316 => '1111::7777:8888:',
    IPv6317 => ':1111::8888',
    IPv6318 => '1111::8888:',
    IPv6319 => '1::1.2.256.4',
    IPv6320 => '1::1.2.300.4',
    IPv6321 => '1::1.2.3.256',
    IPv6322 => '1::1.2.3.300',
    IPv6323 => '1::1.2.3.900',
    IPv6324 => '1::1.256.3.4',
    IPv6325 => '1::1.2.900.4',
    IPv6326 => '1::1.300.3.4',
    IPv6327 => '1::1.900.3.4',
    IPv6328 => '::1.2..',
    IPv6329 => '::1.2.256.4',
    IPv6330 => '::1.2.3.',
    IPv6331 => '1::2::3',
    IPv6332 => '123',
    IPv6333 => '::1.2.300.4',
    IPv6334 => '::1.2.3.256',
    IPv6335 => '::1.2.3.300',
    IPv6336 => ':1.2.3.4',
    IPv6337 => ':::1.2.3.4',
    IPv6338 => '1.2.3.4',
    IPv6339 => '1.2.3.4::',
    IPv6340 => '1.2.3.4:1111:2222:3333:4444::5555',
    IPv6341 => '1.2.3.4:1111:2222:3333::5555',
    IPv6342 => '1.2.3.4:1111:2222::5555',
    IPv6343 => '1.2.3.4:1111::5555',
    IPv6344 => '1.2.3.4::5555',
    IPv6345 => '12345::6:7:8',
    IPv6346 => '1:2:3:4:5:6:7:8:9',
    IPv6347 => '1:2:3::4:5:6:7:8:9',
    IPv6348 => '1:2:3::4:5::7:8',
    IPv6349 => '::1.2.3.900',
    IPv6350 => '1::256.2.3.4',
    IPv6351 => '::1.256.3.4',
    IPv6352 => '1::260.2.3.4',
    IPv6353 => '::1.2.900.4',
    IPv6354 => '1::3000.30.30.30',
    IPv6355 => '1::300.2.3.4',
    IPv6356 => '1::300.300.300.300',
    IPv6357 => '::1.300.3.4',
    IPv6358 => '1:::3:4:5',
    IPv6359 => '1::400.2.3.4',
    IPv6360 => '1::5:1.2.256.4',
    IPv6361 => '1::5:1.2.300.4',
    IPv6362 => '1::5:1.2.3.256',
    IPv6363 => '1::5:1.2.3.300',
    IPv6364 => '1::5:1.2.3.900',
    IPv6365 => '1::5:1.256.3.4',
    IPv6366 => '1::5:1.2.900.4',
    IPv6367 => '1::5:1.300.3.4',
    IPv6368 => '1::5:1.900.3.4',
    IPv6369 => '1::5:256.2.3.4',
    IPv6370 => '1::5:260.2.3.4',
    IPv6371 => '1::5:3000.30.30.30',
    IPv6372 => '1::5:300.2.3.4',
    IPv6373 => '1::5:300.300.300.300',
    IPv6374 => '1::5:400.2.3.4',
    IPv6375 => '1::5:900.2.3.4',
    IPv6376 => '1::900.2.3.4',
    IPv6377 => '::1.900.3.4',
    IPv6378 => '::.2..',
    IPv6379 => '2001:0000:1234:0000:00001:C1C0:ABCD:0876',
    IPv6380 => '2001:0000:1234:',
    IPv6381 => '0000:0000:C1C0:ABCD:0876',
    IPv6382 => '2001:0000:1234:0000:0000:C1C0:ABCD:0876 0',
    IPv6383 => 'ldkfj',
    IPv6384 => '2001:1:1:1:1:1:255Z255X255Y255',
    IPv6385 => '2001:DB8:0:0:8:800:200C:417A:221',
    IPv6386 => '2001:db8:85a3::8a2e:37023:7334',
    IPv6387 => '2001:db8:85a3::8a2e:370k:7334',
    IPv6388 => '2001::FFD3::57ab',
    IPv6389 => '::2222:3333:4444:5555::1.2.3.4',
    IPv6390 => ':2222:3333:4444:5555:6666:1.2.3.4',
    IPv6391 => ':::2222:3333:4444:5555:6666:1.2.3.4',
    IPv6392 => '::2222:3333:4444:5555:6666:7777:1.2.3.4',
    IPv6393 => ':2222:3333:4444:5555:6666:7777:8888',
    IPv6394 => '::2222:3333:4444:5555:6666:7777:8888:',
    IPv6395 => ':::2222:3333:4444:5555:6666:7777:8888',
    IPv6396 => '::2222:3333:4444:5555:6666:7777:8888:9999',
    IPv6397 => '::2222:3333:4444:5555:7777:8888::',
    IPv6398 => '::2222:3333:4444:5555:7777::8888',
    IPv6399 => '::2222:3333:4444:5555::7777:8888',
    IPv6400 => '::2222:3333:4444::6666:1.2.3.4',
    IPv6401 => '::2222:3333:4444::6666:7777:8888',
    IPv6402 => '::2222:3333::5555:6666:1.2.3.4',
    IPv6403 => '::2222:3333::5555:6666:7777:8888',
    IPv6404 => '::2222::4444:5555:6666:1.2.3.4',
    IPv6405 => '::2222::4444:5555:6666:7777:8888',
    IPv6406 => '::.2.3.',
    IPv6407 => '::.2.3.4',
    IPv6408 => '::256.2.3.4',
    IPv6409 => '::260.2.3.4',
    IPv6410 => '::..3.',
    IPv6411 => '::3000.30.30.30',
    IPv6412 => '::300.2.3.4',
    IPv6413 => '::300.300.300.300',
    IPv6414 => ':3333:4444:5555:6666:1.2.3.4',
    IPv6415 => ':3333:4444:5555:6666:7777:8888',
    IPv6416 => '::3333:4444:5555:6666:7777:8888:',
    IPv6417 => ':::3333:4444:5555:6666:7777:8888',
    IPv6418 => '::..3.4',
    IPv6419 => '3ffe:0b00:0000:0001:0000:0000:000a',
    IPv6420 => '3ffe:b00::1::a',
    IPv6421 => '::...4',
    IPv6422 => '::400.2.3.4',
    IPv6423 => ':4444:5555:6666:1.2.3.4',
    IPv6424 => ':::4444:5555:6666:1.2.3.4',
    IPv6425 => ':4444:5555:6666:7777:8888',
    IPv6426 => '::4444:5555:6666:7777:8888:',
    IPv6427 => ':::4444:5555:6666:7777:8888',
    IPv6428 => '::5555:',
    IPv6429 => ':::5555',
    IPv6430 => ':5555:6666:1.2.3.4',
    IPv6431 => ':::5555:6666:1.2.3.4',
    IPv6432 => ':5555:6666:7777:8888',
    IPv6433 => '::5555:6666:7777:8888:',
    IPv6434 => ':::5555:6666:7777:8888',
    IPv6435 => ':6666:1.2.3.4',
    IPv6436 => ':::6666:1.2.3.4',
    IPv6437 => ':6666:7777:8888',
    IPv6438 => '::6666:7777:8888:',
    IPv6439 => ':::6666:7777:8888',
    IPv6440 => ':7777:8888',
    IPv6441 => '::7777:8888:',
    IPv6442 => ':::7777:8888',
    IPv6443 => ':8888',
    IPv6444 => '::8888:',
    IPv6445 => ':::8888',
    IPv6446 => '::900.2.3.4',
    IPv6447 => 'fe80:0000:0000:0000:0204:61ff:254.157.241.086',
    IPv6448 => 'FF01::101::2',
    IPv6449 => 'FF02:0000:0000:0000:0000:0000:0000:0000:0001',
    IPv6450 => '::ffff:192x168.1.26',
    IPv6451 => '::ffff:2.3.4',
    IPv6452 => '::ffff:257.1.2.3',
    IPv6453 => 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:1.2.3.4',
    IPv6454 => 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX',
);

# expected results for ipv6 tests
my @IPv6Results = (
    IPv6001 => 1,
    IPv6002 => 1,
    IPv6003 => 1,
    IPv6004 => 1,
    IPv6005 => 1,

    #        IPv6006 => 1,
    #        IPv6007 => 1,
    IPv6008 => 1,
    IPv6009 => 1,
    IPv6010 => 1,
    IPv6011 => 1,
    IPv6012 => 1,

    #        IPv6013 => 1,
    IPv6014 => 1,

    #        IPv6015 => 1,
    IPv6016 => 1,

    #        IPv6017 => 1,
    IPv6018 => 1,

    #        IPv6019 => 1,
    IPv6020 => 1,

    #        IPv6021 => 1,
    IPv6022 => 1,

    #        IPv6023 => 1,
    IPv6024 => 1,
    IPv6025 => 1,
    IPv6026 => 1,
    IPv6027 => 1,
    IPv6028 => 1,

    #        IPv6029 => 1,
    IPv6030 => 1,
    IPv6031 => 1,
    IPv6032 => 1,

    #        IPv6033 => 1,
    IPv6034 => 1,

    #        IPv6035 => 1,
    IPv6036 => 1,
    IPv6037 => 1,
    IPv6038 => 1,

    #        IPv6039 => 1,
    IPv6040 => 1,

    #        IPv6041 => 1,
    IPv6042 => 1,

    #        IPv6043 => 1,
    IPv6044 => 1,
    IPv6045 => 1,
    IPv6046 => 1,

    #        IPv6047 => 1,
    IPv6048 => 1,

    #        IPv6049 => 1,
    IPv6050 => 1,

    #        IPv6051 => 1,
    IPv6052 => 1,

    #        IPv6053 => 1,
    IPv6054 => 1,
    IPv6055 => 1,
    IPv6056 => 1,

    #        IPv6057 => 1,
    IPv6058 => 1,

    #        IPv6059 => 1,
    IPv6060 => 1,
    IPv6061 => 1,

    #        IPv6062 => 1,
    #        IPv6063 => 1,
    IPv6064 => 1,
    IPv6065 => 1,

    #        IPv6066 => 1,
    IPv6067 => 1,
    IPv6068 => 1,

    #        IPv6069 => 1,
    #        IPv6070 => 1,
    IPv6071 => 1,
    IPv6072 => 1,

    #        IPv6073 => 1,
    IPv6074 => 1,
    IPv6075 => 1,
    IPv6076 => 1,
    IPv6077 => 1,
    IPv6078 => 1,
    IPv6079 => 1,
    IPv6080 => 1,

    #        IPv6081 => 1,
    IPv6082 => 1,
    IPv6083 => 1,

    #        IPv6084 => 1,
    IPv6085 => 1,
    IPv6086 => 1,

    #        IPv6087 => 1,
    #        IPv6088 => 1,
    #        IPv6089 => 1,
    IPv6090 => 1,
    IPv6091 => 1,
    IPv6092 => 1,
    IPv6093 => 1,
    IPv6094 => 1,
    IPv6095 => 1,
    IPv6096 => 1,
    IPv6097 => 1,
    IPv6098 => 1,
    IPv6099 => 1,
    IPv6100 => 1,
    IPv6101 => 1,
    IPv6102 => 1,
    IPv6103 => 1,
    IPv6104 => 1,
    IPv6105 => 1,
    IPv6106 => 1,
    IPv6107 => 1,
    IPv6108 => 1,
    IPv6109 => 1,
    IPv6110 => 1,

    #        IPv6111 => 1,
    IPv6112 => 1,
    IPv6113 => 1,
    IPv6114 => 1,
    IPv6115 => 1,
    IPv6116 => 1,
    IPv6117 => 1,
    IPv6118 => 1,
    IPv6119 => 1,
    IPv6120 => 1,

    #        IPv6121 => 1,
    IPv6122 => 1,

    #        IPv6123 => 1,
    IPv6124 => 1,

    #        IPv6125 => 1,
    IPv6126 => 1,
    IPv6127 => 1,
    IPv6128 => 1,
    IPv6129 => 1,
    IPv6130 => 1,
    IPv6131 => 1,
    IPv6132 => 1,

    #        IPv6133 => 1,
    IPv6134 => 1,
    IPv6135 => 1,

    #        IPv6136 => 1,
    IPv6137 => 1,

    #        IPv6138 => 1,
    IPv6139 => 1,
    IPv6140 => 1,
    IPv6141 => 1,
    IPv6142 => 1,
    IPv6143 => 1,
    IPv6144 => 1,
    IPv6145 => 1,

    #        IPv6146 => 1,
    #        IPv6147 => 1,
    #        IPv6148 => 1,
    #        IPv6149 => 1,
    #        IPv6150 => 1,
    IPv6151 => 1,
);

# test variables for ipv4 tests
my @IPv4Variables = (
    IPv41  => '192.168.0.1',
    IPv42  => '0.0.0.0',
    IPv43  => '255.255.255.255',
    IPv44  => '192.168.0.',
    IPv45  => '192.168.0',
    IPv46  => '256.0.0.0',
    IPv47  => '333.0.0.0',
    IPv48  => '0.0.0.256',
    IPv49  => '192..168.0',
    IPv410 => '01.23.45.67',
);

# IsArrayRefWithData
$ExpectedTestResults = {
    ArrayRef => 1,
};
$TestVariables = {
    @CommonVariables,
};
$RunTests->( 'IsArrayRefWithData', $TestVariables, $ExpectedTestResults );

# IsHashRefWithData
$ExpectedTestResults = {
    HashRef => 1,
};
$TestVariables = {
    @CommonVariables,
};
$RunTests->( 'IsHashRefWithData', $TestVariables, $ExpectedTestResults );

# IsInteger
$ExpectedTestResults = {
    String  => 1,
    Number1 => 1,
    Number2 => 1,
    Number3 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsInteger', $TestVariables, $ExpectedTestResults );

# IsIPv4Address
$ExpectedTestResults = {
    IPv41 => 1,
    IPv42 => 1,
    IPv43 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
    @IPv4Variables,
};
$RunTests->( 'IsIPv4Address', $TestVariables, $ExpectedTestResults );

# IsIPv6Address
$ExpectedTestResults = {
    @IPv6Results,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
    @IPv6Variables,
};
$RunTests->( 'IsIPv6Address', $TestVariables, $ExpectedTestResults );

# IsMD5Sum
$ExpectedTestResults = {
    MD5Sum1 => 1,
    MD5Sum2 => 1,
    MD5Sum3 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
    MD5Sum1 => '0123456789abcdef0123456789ABCDEF',
    MD5Sum2 => '00000000000000000000000000000000',
    MD5Sum3 => 'ffffffffffffffffffffffffffffffff',
    MD5Sum4 => '0000000000000000000000000000000g',
    MD5Sum5 => '0123456789abcdef',
    MD5Sum6 => '000000000000000000000000000000000',
    MD5Sum7 => '000000000000000000-00000000000000',
};
$RunTests->( 'IsMD5Sum', $TestVariables, $ExpectedTestResults );

# IsNumber
$ExpectedTestResults = {
    String   => 1,
    Number1  => 1,
    Number2  => 1,
    Number3  => 1,
    Number4  => 1,
    Number5  => 1,
    Number6  => 1,
    Number7  => 1,
    Number8  => 1,
    Number9  => 1,
    Number10 => 1,
    Number11 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsNumber', $TestVariables, $ExpectedTestResults );

# IsPositiveInteger
$ExpectedTestResults = {
    Number1 => 1,
    Number2 => 1,
};
$TestVariables = {
    @CommonVariables,
    @NumberVariables,
};
$RunTests->( 'IsPositiveInteger', $TestVariables, $ExpectedTestResults );

# IsString
$ExpectedTestResults = {
    String      => 1,
    StringEmpty => 1,
    String1     => 1,
    String2     => 1,
    String3     => 1,
    String4     => 1,
    String5     => 1,
};
$TestVariables = {
    @CommonVariables,
    String1 => '123',
    String2 => 'abc',
    String3 => 'äöüß€ис',
    String4 => ' ',
    String5 => "\t",
};
$RunTests->( 'IsString', $TestVariables, $ExpectedTestResults );

# IsStringWithData
$ExpectedTestResults = {
    String  => 1,
    String1 => 1,
    String2 => 1,
    String3 => 1,
    String4 => 1,
    String5 => 1,
};
$TestVariables = {
    @CommonVariables,
    String1 => '123',
    String2 => 'abc',
    String3 => 'äöüß€ис',
    String4 => ' ',
    String5 => "\t",
};
$RunTests->( 'IsStringWithData', $TestVariables, $ExpectedTestResults );

#
# DataIsDifferent tests
#

my %Hash1 = (
    key1 => '1',
    key2 => '2',
    key3 => {
        test  => 2,
        test2 => [
            1, 2, 3,
        ],
    },
    key4 => undef,
);

my %Hash2 = %Hash1;
$Hash2{AdditionalKey} = 1;

my @List1 = ( 1, 2, 3, );
my @List2 = (
    1,
    2,
    4,
    [ 1, 2, 3 ],
    {
        test => 'test',
    },
);

my $Scalar1 = 1;
my $Scalar2 = {
    test => [ 1, 2, 3 ],
};

my $Count = 0;
for my $Value1 ( \%Hash1, \%Hash2, \@List1, \@List2, \$Scalar1, \$Scalar2 ) {
    $Count++;
    $Self->Is(
        scalar DataIsDifferent(
            Data1 => $Value1,
            Data2 => $Value1
        ),
        scalar undef,
        'DataIsDifferent() - Test ' . $Count,
    );

    my $Count2 = 0;
    VALUE2: for my $Value2 ( \%Hash1, \%Hash2, \@List1, \@List2, \$Scalar1, \$Scalar2 ) {
        if ( $Value2 == $Value1 ) {
            next VALUE2;
        }
        $Count2++;

        $Self->Is(
            scalar DataIsDifferent(
                Data1 => $Value1,
                Data2 => $Value2
            ),
            1,
            'DataIsDifferent() - Test ' . $Count . ':' . $Count2,
        );
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
