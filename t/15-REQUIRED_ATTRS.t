use Test::More 'no_plan';
use strict;
use warnings;

package B1;
use Simo;
sub b1{ ac }
sub b2{ ac }
sub b3{ ac }

sub REQUIRED_ATTRS{ qw( b1 b2 ) }


package main;
{
    eval{ B1->new( b1 => 1 ) };
    like( $@, qr/Attr 'b2' is required/, 'attr required' );
    is_deeply( [ $@->type, $@->pkg, $@->attr ], [ 'attr_required', 'B1', 'b2' ], 'required key to new. Simo::Error object' );
}

