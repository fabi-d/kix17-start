#!/usr/bin/perl -w
# --
# Copyright (C) 2001-2016 c.a.p.e. IT GmbH, http://www.cape-it.de/
#
# written/edited by:
# * Ralf(dot)Boehm(at)cape(dash)it(dot)de
# * Rene(dot)Boehm(at)cape(dash)it(dot)de
#
# --
# $Id$
# --
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU AFFERO General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
# or see http://www.gnu.org/licenses/agpl.txt.
# --

use strict;
use warnings;

use File::Basename;
use FindBin qw($RealBin);
use lib dirname($RealBin).'/../../';
use lib dirname($RealBin).'/../../Kernel/cpan-lib';

use Getopt::Std;
use File::Path qw(mkpath);

use Kernel::System::ObjectManager;

# create object manager
local $Kernel::OM = Kernel::System::ObjectManager->new(
    'Kernel::System::Log' => {
        LogPrefix => 'kix-upgrade-to-17.pl',
    },
);

use vars qw(%INC);

my %Opts;
getopt( 'f', \%Opts );

# create database tables and insert initial values
my $XMLFile = $Kernel::OM->Get('Kernel::Config')->Get('Home').'/scripts/database/update/kix-upgrade-'.$Opts{f}.'-to-17.xml';
if ( ! -f "$XMLFile" ) {
    print STDERR "File \"$XMLFile\" doesn't exist!"; 
    exit -1;
}
my $XML = $Kernel::OM->Get('Kernel::System::Main')->FileRead(
    Location => $XMLFile,
);
if (!$XML) {
    print STDERR "Unable to read file \"$XMLFile\"!"; 
    exit -1;
}

my @XMLArray = $Kernel::OM->Get('Kernel::System::XML')->XMLParse(
    String => $XML,
);
if (!@XMLArray) {
    print STDERR "Unable to parse file \"$XMLFile\"!"; 
    exit -1;
}

my @SQL = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessor(
    Database => \@XMLArray,
);
if (!@SQL) {
    print STDERR "Unable to create SQL from file \"$XMLFile\"!"; 
    exit -1;
}

for my $SQL (@SQL) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute SQL from file \"$XMLFile\"!"; 
        exit -1;
    }
}

# execute post SQL statements (indexes, constraints)
my @SQLPost = $Kernel::OM->Get('Kernel::System::DB')->SQLProcessorPost();
for my $SQL (@SQLPost) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL => $SQL 
    );
    if (!$Result) {
        print STDERR "Unable to execute POST SQL!"; 
        exit -1;
    }
}

# check for Pro packages
my $IsPro = 0;
my $Result = $Kernel::OM->Get('Kernel::System::DB')->Prepare(
    SQL => 'SELECT count(*) FROM package_repository where name = \'KIXBasePro\'',
    Limit => 1,
);
if (!$Result) {
    print STDERR "Unable to execute SQL to check for KIX Professional!"; 
}
else {
    while ( my @Row = $Kernel::OM->Get('Kernel::System::DB')->FetchrowArray() ) {
        $IsPro = ($Row[0] > 0);
    }
}

# delete all obsolete packages
my @ObsoletePackages = (
    'KIXBase',
    'NotificationEventX',
    'TicketPrintRichtext',
    'KIXSidebarTools',
    'BPMX',
    'KIX4OTRS',
    'KIXCore',
    'QueuesGroupsRoles',
    'HidePendingTimeInput',
    'ExternalSupplierForwarding',
    'TemplateX',
    'ServiceImportExport',
    'UserImportExport',
    'CustomerCompanyImportExport',
    'CustomerUserImportExport',
    'FAQImportExport',
    'DynamicFieldRemoteDB',
    'DynamicFieldITSMConfigItem',
    'SystemMonitoringX',
    'ITSM',
    'ITSMIncidentProblemManagement',
    'ITSMServiceLevelManagement',
    'ITSMConfigurationManagement',
    'ITSMCore',
    'ITSM-CIAttributeCollection',
    'ImportExport',
    'GeneralCatalog',
    'FAQ',
);

if ($IsPro) {
    @ObsoletePackages = (
        @ObsoletePackages,
        'KIXWidespreadIncident',
        'KIXTemplateWorkflows',
        'KIXServiceCatalog',
        'KIXOptimizedCMDB',
        'ITSM-CIAdminModules',
        'InventorySync',
        'FileExchange',
        'KIXCMDBExplorer',
        'CMDB4Customer',
        'KIXCalendar',
    );

    my $XMLPackageContent = <<'EOT';
<?xml version="1.0" encoding="utf-8" ?>
<kix_package version="1.1">
    <Name>KIXPro</Name>
    <Version>16.1.0</Version>
</kix_package>
EOT
    
    # create "fake" KIXPro package entry for update installation
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL  => "UPDATE package_repository SET name = 'KIXPro', version = '16.1.0', content = ? WHERE name = ?",
        Bind => [
            \$XMLPackageContent,
            \'KIXBasePro',
        ],
    );
    if (!$Result) {
        print STDERR "Unable to create package entry \"KIXPro\" in package repository!"; 
    }
    
    # create "fake" directory for update installation
    my $Home = $Kernel::OM->Get('Kernel::Config')->Get('Home');
    if ( !( -e $Home.'/KIXPro' ) ) {
        if ( !mkpath( $Home.'/KIXPro', 0, 0755 ) ) {
            print STDERR "Can't create directory '$Home/KIXpro'!";
        }
    }
}

foreach my $Package (@ObsoletePackages) {
    my $Result = $Kernel::OM->Get('Kernel::System::DB')->Do( 
        SQL  => "DELETE FROM package_repository WHERE name = ?",
        Bind => [
            \$Package,
        ],
    );
    if (!$Result) {
        print STDERR "Unable to remove package \"$Package\" from package repository!"; 
    }
}

exit 1;
