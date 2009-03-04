use Test::More 'no_plan';
use strict;
use warnings;

package T1;
sub new{ 
    my $proto = shift;
    my $class = ref $proto || $proto;
    return bless { @_ }, $class;
}

package T2;
use Simo( base => 'T1' );

sub a3{ ac }
sub a4{ ac }

sub new{
    return shift->new_self_and_parent( @_, [ 'a1', 'a2' ] );
}

package T3;
use Simo( base => 'T1' );

sub a3{ ac }
sub a4{ ac }

sub new{
    my ( $self, $simo_args, $parent_args ) = @_;
    return shift->new_self_and_parent( { parent_args => [ a1 => 1, a2 => 2 ], self_args => [ a3 => 3, a4 => 4 ] } );
}

package main;
{
    my $t = T2->new( a1 => 1, a2 => 2, a3 => 3, a4 => 4 );
    isa_ok( $t, 'T2' );
    is_deeply( $t, { a1 => 1, a2 => 2, a3 => 3, a4 => 4 }, 'test' );
}

{
    my $t = T3->new;
    isa_ok( $t, 'T3' );
    is_deeply( $t, { a1 => 1, a2 => 2, a3 => 3, a4 => 4 }, 'test' );
}

package T4;
use Simo;

package main;
{
    eval{ T4->new_self_and_parent };
    like( $@, qr/Cannot call 'new_self_and_parent' from the class having no parent/, 'parent is Simo' );
}

package T5;

sub a1{ }

1;

package T6;
use Simo( base => 'T5' );

package main;
{
    eval{ T6->new_self_and_parent };
    like( $@, qr/'T5' do not have 'new'/, 'parent do not have new' );
}


{
    eval{ T2->new_self_and_parent( 1 ) };
    like( $@, qr/'new_self_and_parent' argument is invalid/, 'arg is invalid' );
}

{
    eval{ T2->new_self_and_parent( { self_args => 1, parent_args => [] } ) };
    like( $@, qr/'self_args' must be array reference/, 'arg is invalid' );
}

{
    eval{ T2->new_self_and_parent( { self_args => [], parent_args => 1 } ) };
    like( $@, qr/'parent_args' must be array reference/, 'arg is invalid' );
}

package T7;
sub new{ return bless [], 'T7' }

package T8;
use Simo( base => 'T7' );
sub a1{ ac }

package main;
eval{ T8->new_self_and_parent( { self_args => [], parent_args => [] } ) };
like( $@, qr/'T7' must be the class based on hash reference/, 'parent must be class based on hash referenece' );


__END__

