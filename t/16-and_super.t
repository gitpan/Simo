use Test::More 'no_plan';
use strict;
use warnings;

package B1;
use Simo;
sub b1{ ac }
sub b2{ ac }
sub b3{ ac }

sub REQUIRED_ATTRS{ qw( b1 b2 ) }

package B2;
use Simo( base => 'B1' );
sub b4{ ac }

sub REQUIRED_ATTRS{ 'b4', and_super }

package B3;
use Simo( base => 'B2' );
sub b5{ ac }

sub REQUIRED_ATTRS{ qw( b5 ), and_super }

package main;
{
    my @required_attrs = B3->REQUIRED_ATTRS;
    is_deeply( [ @required_attrs ], [ 'b5', 'b4', 'b1', 'b2' ], 'and_super' );
    
    use Simo;
    eval{ Simo::and_super( 1 ) };
    like( $@, qr/Cannot pass args to 'and_super'/, 'args error' );
}

