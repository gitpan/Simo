use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Simo',
    AUTHOR              => 'Yuki Kimoto <kimoto.yuki@gmail.com>',
    VERSION_FROM        => 'lib/Simo.pm',
    ABSTRACT_FROM       => 'lib/Simo.pm',
    ($ExtUtils::MakeMaker::VERSION >= 6.3002
      ? ('LICENSE'=> 'perl')
      : ()),
    PL_FILES            => {},
    PREREQ_PM => {
        'Test::More' => 0,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Simo-*' },
);
