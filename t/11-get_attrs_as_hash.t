use strict;
use warnings;

use Test::More 'no_plan';

package T1;
use Simo;

sub x{ ac default => 1 }
sub y{ ac default => 2 }

package main;
{
    my $t = T1->new;
    my %point = $t->get_attrs_as_hash( 'x', 'y' );
    is_deeply( { %point }, { x => 1, y => 2 }, 'list context' );
    
    my $point = $t->get_attrs_as_hash( 'x', 'y' );
    is_deeply( $point, { x => 1, y => 2 }, 'scalar context' );
}
