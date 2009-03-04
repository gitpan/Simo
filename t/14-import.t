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

package T5;
use Simo( new => 'T1' );

package main;
{
    my $t = T5->new;
    isa_ok( $t, 'T1' );
}

package T6;
use Simo( new => [ 'T1', 'T2' ] );

package main;
{
    my $t = T6->new;
    isa_ok( $t, 'T1' );
    isa_ok( $t, 'T2' );
}

package B3;
sub b1{};

package B4::A;
sub b2{}

package M3;
sub m1{}

package M4;
sub m2{}

package N1;
use Simo( base => 'B3' );
sub new{ shift->SUPER::new( @_ ) }

package T7;
use Simo { base => [ 'B3', 'B4::A' ], new => 'N1', mixin => [ 'M3', 'M4' ] };

sub a1{ ac }

sub new{ return shift->SUPER::new( @_ ) }

package main;
{
     my $t = T7->new( a1 => 1 );
     $t->can( 'a1' );
     is( $t->a1, 1, 'new' );
     
     is_deeply( [ @T7::ISA ], [ qw( N1 B4::A M3 M4 ) ], 'inherit order' );   
}
