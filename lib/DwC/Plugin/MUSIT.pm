use 5.024003;
use strict;
use warnings;
use utf8;

use POSIX;
use Geo::WKT;

use locale;

use Local::gbifno::latlon;
use Local::gbifno::mgrs;
use Local::gbifno::utm;

package DwC::Plugin::MUSIT;

our $VERSION = '0.01';

sub description {
  return "Cleans MUSIT data";
}

sub guess {
  local $_ = shift || "";
  s/^\s+|\s+$//g;
  if(/^$/) {
    "";
  } elsif(/^\d{2}\w{1}\s\w{2}\s\d+,\s\d+$/) {
    "MGRS";
  } elsif(/^\d{2}\w{1}\s\w{2}\d+$/) {
    "MGRS";
  } elsif(/^\d{2}\w{1}\s\w{2}\s\d+\s+\d+$/) {
    "MGRS";
  } elsif(/^\d{2}\w{1}\s\w{2}\s[\d\-,]+$/) {
    "MGRS";
  } elsif(/^\d{2}\w{1}\s\w{2}-\w{2}\s[\d\-,]+$/) {
    "MGRS";
  } elsif(/^\d{2}\s*\w{2}\s*[\d\-\,]+$/) {
    "MGRS";
  } elsif(/^\d{2}\s*\w{2}-\w{2}\s*[\d\-\,]+$/) {
    "MGRS";
  } elsif(/^\d{2}\w\w{2}[\d,]+\w{2}[\d,]+$/) {
    "MGRS";
  } elsif(/^\d+\.\d+[NS] \d+\.\d+[EW]$/) {
    "decimal degrees";
  } elsif(/^\d+\s+\d+[NSEW]\s+\d+\s+\d+[NSEW]$/) {
    "degrees minutes seconds";
  } elsif(/^\d+\s*[\d\.]+[NS]\s*\d+\s*[\d\.]+[EW]$/) {
    "degrees minutes seconds";
  } elsif(/^\s*[\d\.°,]+\s*[NSEW]\s*[\d\.°,]+\s*[NSEW]\s*$/) {
    "decimal degrees";
  } elsif(/^Long&Lat:/) {
    "decimal degrees";
  } elsif(/^[\d,\s]+\s*°\s*[NSEW]?\s*[\d,\s]+\s*°\s*[NSEW]?$/) {
    "decimal degrees";
  } elsif(/^[\d,\s]+\s*[NSEW]\s*[\d,\s]+\s*[NSEW]$/) {
    "decimal degrees";
  } elsif(/^(Lat\.)?\s*[NSEW\s\d,°-]+\s*[\d-,]+'/) {
    "degrees minutes seconds";
  } elsif(/^\d+°\s*[\d\.]+'\s*[NSEW]\s+\d+°\s*[\d\.]+'\s*[NSEW]$/) {
    "degrees minutes seconds";
  } elsif(/^\d{2}[A-Z]\s+\d+\s+\d+$/) {
    "UTM";
  } elsif(/(\d+)[A-Z]\s*[A-Z]?\s*(\d+),(\d+)/) {
    "UTM";
  } elsif(/^[NØ]\d+[\s,]+[NØ]\d+\.?$/) {
    "UTM";
  } elsif(/UTM/) {
    "UTM";
  } elsif(/^Euref\. 89 (\d+)/) {
    "UTM (Euref.89)";
  } elsif(/^\s*\w{2}\s\d+\,\d+\s*$/) {
    "Broken MGRS";
  } elsif(/^\s*rikets nät/i) {
    "Rikets nät";
  } elsif(/^\s*RN/i) {
    "Rikets nät";
  } elsif(/^\s*[\-\d\.]+\s[\-\d\.]+\s*$/) {
    "decimal degrees";
  } elsif(/^\s*\d{2}\w\s\w{2}\s\d+\,\d+\s*$/) {
    "MGRS";
  } elsif(/^\s*\w{2}\s*[\d\-\,]+$/) {
    "Broken MGRS";
  } else {
    "Unknown";
  }
};

our %months = (
  "jan" => "01", "feb" => "02", "mar" => "03", "apr" => "04",
  "mai" => "05", "jun" => "06", "jul" => "07", "aug" => "08",
  "sep" => "09", "okt" => "10", "nov" => "11", "des" => "12"
);

sub parsedate {
  local $_ = shift;
  return if(!$_);
  my ($d, $mon, $y) = split /[\s\-]/;
  my $m = $months{$mon};
  return "$y-$m-$d";
}

sub terms {
  return ( "dcterms:license", "year", "month", "day" );
}

sub clean {
  my ($plugin, $dwc) = @_;
  return if($ENV{DWC_HANDSOFF});

  if ($$dwc{eventDate} && $$dwc{eventDate} eq "0000-00-00") {
    $dwc->log("info", "Removed invalid eventDate", "core");
    $$dwc{eventDate} = "";
  }
  if ($$dwc{dateIdentified} && $$dwc{dateIdentified} eq "0000-00-00") {
    $dwc->log("info", "Removed invalid dateIdentified", "core");
    $$dwc{dateIdentified} = "";
  }

  if($$dwc{eventDate} && $$dwc{eventDate} =~ /\-/) {
    if(!$$dwc{year} && !$$dwc{month} && !$$dwc{day}) {
      my ($y, $m, $d) = split /-/, $$dwc{eventDate};
      $$dwc{year} = $y if $y != 0;
      $$dwc{month} = $m if $m != 0;
      $$dwc{day} = $d if $d != 0;
      $dwc->log("info", "Split eventDate into year, month and day",
        "core");
    }
  }

  $$dwc{'dcterms:modified'} = parsedate($$dwc{'dcterms:modified'});
  $$dwc{'dcterms:license'} = $$dwc{CreativeCommonsLicense};

  my $system = guess($$dwc{verbatimCoordinates});
  if($system eq "Broken MGRS") {
    $dwc->log("warning", "MGRS coordinates are incomplete", "geography");
    $system = "MGRS";
  }

  if(!$system) {
    $$dwc{verbatimCoordinateSystem} = "";
    $$dwc{decimalLatitude} = "";
    $$dwc{decimalLongitude} = "";
  } elsif($system eq "MGRS") {
    eval {
      my ($mgrs,$d,@b) = Local::gbifno::mgrs::parse($$dwc{verbatimCoordinates});
      if($mgrs) {
        $$dwc{verbatimCoordinateSystem} = "MGRS";
        $$dwc{coordinates} = uc $mgrs;
        if(!$$dwc{coordinateUncertaintyInMeters}) {
          $$dwc{coordinateUncertaintyInMeters} = $d;
        }
        $$dwc{decimalLatitude} = ""; $$dwc{decimalLongitude} = "";
        if(@b) {
          my $wgs84 = Geo::Proj4->new(init => "epsg:4326");
          if($$dwc{verbatimSRS} && $$dwc{verbatimSRS} eq "ED50") {
            @b = map {
              my $ed50 = Geo::Proj4->new("+proj=utm +zone=$$_[0] \
                +ellps=intl +units=m +towgs84=-87,-98,-121");
              $ed50->transform($wgs84, [$$_[1], $$_[2]]);
            } @b;
          } else {
            @b = map {
              my $ed50 = Geo::Proj4->new("+proj=utm +zone=$$_[0] +units=m");
              $ed50->transform($wgs84, [$$_[1], $$_[2]]);
            } @b;
          }
          $$dwc{footprintWKT} = Geo::WKT::wkt_polygon(@b);
        }
      } else {
        die "parseMGRS failed disastrously";
      }
    };
    if($@) {
      my $warning = $@ =~ s/\s+$//r =~ s/ at.*//r;
      $dwc->log("warning", $warning, "parseMGRS", "geography");
      $$dwc{decimalLatitude} = "";
      $$dwc{decimalLongitude} = "";
      $$dwc{verbatimCoordinateSystem} = "Unknown";
    }
  } elsif($system eq "UTM") {
    my $utm;
    eval {
      $utm = Local::gbifno::utm::parse($$dwc{verbatimCoordinates});
    };
    if($@) {
      $dwc->log("warning", "Unable to parse UTM coordinates", "geography");
    }
    if($utm) {
      $$dwc{coordinates} = $utm;
      $$dwc{verbatimCoordinateSystem} = "UTM";
    } else {
      $$dwc{verbatimCoordinateSystem} = "";
    }
  } elsif($system eq "decimal degrees") {
    eval {
      my $raw = $$dwc{verbatimCoordinates};
      my ($lat, $lon) = Local::gbifno::latlon::parsedec($raw);
      $$dwc{decimalLatitude} = $lat;
      $$dwc{decimalLongitude} = $lon;
      $$dwc{verbatimCoordinateSystem} = "decimal degrees";
    };
    if($@) {
      my $warning = $@ =~ s/\s+$//r =~ s/ at.*//r;
      $dwc->log("warning", $warning, "parseDecimalDegrees", "geography");
      $$dwc{decimalLatitude} = "";
      $$dwc{decimalLongitude} = "";
      $$dwc{verbatimCoordinateSystem} = "Unknown";
    }
  } elsif($system eq "degrees minutes seconds") {
    eval {
      my $raw = $$dwc{verbatimCoordinates};
      my ($lat, $lon) = Local::gbifno::latlon::parsedeg($raw);
      $$dwc{decimalLatitude} = $lat;
      $$dwc{decimalLongitude} = $lon;
      $$dwc{verbatimCoordinateSystem} = "degrees minutes seconds";
    };
    if($@) {
      my $warning = $@ =~ s/\s+$//r =~ s/ at.*//r;
      $dwc->log("warning", $warning, "parseDegrees", "geography");
      $$dwc{decimalLatitude} = "";
      $$dwc{decimalLongitude} = "";
      $$dwc{verbatimCoordinateSystem} = "Unknown";
    }
  } elsif($system eq "Rikets nät") {
    $$dwc{decimalLatitude} = "";
    $$dwc{decimalLongitude} = "";
    if($$dwc{verbatimCoordinates} =~ /^rikets nät (.*)$/) {
      $$dwc{verbatimCoordinates} = $1;
    }
    $$dwc{verbatimCoordinateSystem} = "RT90";
  } elsif($system =~ "Unknown") {
    $dwc->log("warning", "Unknown coordinate system", "geography");
    $$dwc{decimalLatitude} = "";
    $$dwc{decimalLongitude} = "";
    $$dwc{coordinateUncertaintyInMeters} = "";
    $$dwc{verbatimCoordinateSystem} = "unknown";
  }

  if($$dwc{verbatimSRS}) {
    if($$dwc{verbatimSRS} eq "ED50") {
      $$dwc{geodeticDatum} = "European 1950";
    } elsif($$dwc{verbatimSRS} eq "WGS84") {
      $$dwc{geodeticDatum} = "WGS84";
    }
  } else {
    $$dwc{geodeticDatum} = "";
  }

  return $dwc;
}

1;

__END__

=head1 NAME

DwC::Plugin::MUSIT - data cleaning specific to MUSIT datasets

=head1 SYNOPSIS

Datasets from MUSIT contain coordinates in a variety of systems – MGRS, UTM,
RT90, decimal degrees and degrees/minutes/seconds.

Since the verbatimCoordinateSystem field is not used at all, this plugin does
its best to guess the correct coordinate system.

In addition to this, it does some basic date cleaning, like getting rid of
I"0000-00-00".

=head1 AUTHOR

umeldt

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2018 by umeldt

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.24.3 or,
at your option, any later version of Perl 5 you may have available.

=cut
