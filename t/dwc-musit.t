use strict;
use warnings;
use utf8;

use Test::More tests => 8;
BEGIN { use_ok('DwC::Plugin::MUSIT') };

ok(DwC::Plugin::MUSIT::guess("32VKM10001000") eq "MGRS");
ok(DwC::Plugin::MUSIT::guess("17N 1 4833438") eq "UTM");
ok(DwC::Plugin::MUSIT::guess("32.5 12.374") eq "decimal degrees");
ok(DwC::Plugin::MUSIT::guess("5° 0' 3.6\"S 77° 2' 5\" W") eq
  "degrees minutes seconds");
ok(DwC::Plugin::MUSIT::guess("RN 6404510 1271140") eq "Rikets nät");
ok(DwC::Plugin::MUSIT::guess("bak låven") eq "Unknown");
ok(DwC::Plugin::MUSIT::guess("VK123142") eq "Broken MGRS");

