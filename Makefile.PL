use 5.024003;
use ExtUtils::MakeMaker;

WriteMakefile(
  NAME              => 'DwC::Plugin::MUSIT',
  VERSION_FROM      => 'lib/DwC/Plugin/MUSIT.pm',
  PREREQ_PM         => { DwC => 0.01, 'Local::gbifno' => 0.01 },
  ABSTRACT_FROM     => 'lib/DwC/Plugin/MUSIT.pm',
  AUTHOR            => 'umeldt <chris@svindseth.jp>',
  LICENSE           => 'perl',
);
