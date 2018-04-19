use strict;
use warnings;
use utf8;

use DwC;

use Test::More tests => 12;
BEGIN { use_ok('DwC::Plugin::MUSIT') };

ok(DwC::Plugin::MUSIT::guess("32VKM10001000") eq "MGRS");
ok(DwC::Plugin::MUSIT::guess("17N 1 4833438") eq "UTM");
ok(DwC::Plugin::MUSIT::guess("32.5 12.374") eq "decimal degrees");
ok(DwC::Plugin::MUSIT::guess("5° 0' 3.6\"S 77° 2' 5\" W") eq
  "degrees minutes seconds");
ok(DwC::Plugin::MUSIT::guess("RN 6404510 1271140") eq "Rikets nät");
ok(DwC::Plugin::MUSIT::guess("bak låven") eq "Unknown");
ok(DwC::Plugin::MUSIT::guess("VK123142") eq "Broken MGRS");

my $dwc = DwC->new({ verbatimCoordinates => "????" });
DwC::Plugin::MUSIT->clean($dwc);
ok($$dwc{verbatimCoordinateSystem} eq "unknown");

$dwc = DwC->new({ verbatimCoordinates => "32VNT124124" });
DwC::Plugin::MUSIT->clean($dwc);
ok($$dwc{verbatimCoordinateSystem} eq "MGRS");

$dwc = DwC->new({ verbatimCoordinates => "rikets nät 1234" });
DwC::Plugin::MUSIT->clean($dwc);
ok($$dwc{verbatimCoordinateSystem} eq "RT90");

$dwc = DwC->new({ verbatimCoordinates => "UTM(32)583319,6549544" });
DwC::Plugin::MUSIT->clean($dwc);
ok($$dwc{verbatimCoordinateSystem} eq "UTM");

