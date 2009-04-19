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
        'Simo::Error' => 0.0206
    },
    requires => {
        'Storable' => 0,
        'Simo::Util' => 0.0301
    },
    add_to_cleanup      => [ 'Simo-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
