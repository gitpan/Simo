use Test::More 'no_plan';
use strict;
use warnings;

package B1;
sub b1{};

package B2::A;
sub b2{}

package M1;
sub m1{}

package M2;
sub m2{}

package T1;
use Simo( base => 'B1', mixin => 'M1' );

package main;
{
    my $t = T1->new;
    ok( $t->can( 'b1' ), 'base option passed as string' );
    ok( $t->can( 'm1' ), 'mixin option passed as string' );
}

package T2;
use Simo { base => [ 'B1', 'B2::A' ], mixin => [ 'M1', 'M2' ] };

package main;
{
     my $t = T2->new;
     ok( $t->can( 'b1' ), 'base option passed as array ref 1' );   
     ok( $t->can( 'b2' ), 'base option passed as array ref 2' );   

     ok( $t->can( 'm1' ), 'mixin option passed as array ref 1' );   
     ok( $t->can( 'm2' ), 'mixin option passed as array ref 2' );
     
     is_deeply( [ @T2::ISA ], [ qw( B1 B2::A Simo M1 M2 ) ], 'inherit order' );   
}

package T3;
eval"use Simo( a => 'B1' )";
package main;
like( $@, qr/Invalid import option 'a'/, 'Invalid import option' );

package T4;
eval"use Simo( base => 'B2:A' )";
package main;
like( $@, qr/Invalid class name 'B2:A'/, 'Invalid class name' );


