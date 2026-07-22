use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME              => 'PascalObject',
    VERSION           => '0.01',
    PREREQ_PM         => {'DynaLoader'},
    ABSTRACT          => 'Bridge for using Pascal objects from Perl',
    AUTHOR            => 'Bartosz Jarzyna',
    LICENSE           => 'BSD3',
    LIBS              => [''],
    DEFINE            => '',
    INC               => '-I.',
    OBJECT            => '$(O_FILES)',
    XS                => { 'PascalObject.xs' => 'PascalObject.c' },
    C                 => ['PascalObject.c'],
);

