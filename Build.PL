use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Simo',
    license             => 'perl',
    dist_author         => 'Yuki <kimoto.yuki@gmail.com>',
    dist_version_from   => 'lib/Simo.pm',
    build_requires => {
        'Test::More' => 0,
    },
    requires => {
        'Storable' => 0,
        'Simo::Util' => 0.0301,
        'Simo::Constrain' => 0.0201,
        'Simo::Error' => 0.0207
    },
    add_to_cleanup      => [ 'Simo-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
