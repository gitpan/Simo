use Test::More 'no_plan';
use strict;
use warnings;

package T1;
use Simo;

sub a1{ ac }

sub m1{
    my ( $self, @args ) = @_;
    $self->a1( \@args );
}

sub m2{
    my $self = shift;
    wantarray ? @{ $self->a1 } : $self->a1;
}

package main;
$SIG{__WARN__} = sub{};
{
    my $t = T1->new;
    my $ret = $t->run_methods(
        m1 => [ 1, 2 ],
        'm2'
    );
    is_deeply( $ret, [ 1, 2 ], 'scalar context' );
}

{
    my $t = T1->new;
    my @rets = $t->run_methods(
        m1 => [ 1, 2 ],
        'm2'
    );
    is_deeply( [ @rets ], [ 1, 2 ], 'list context' );
}

{
    my $t = T1->new;
    eval{ $t->run_methods( {} ) };
    like( $@, qr/is bad\. Method name must be string and args must be array ref/, 'bad method name' );
    
    eval{ $t->run_methods( '1' ) };
    like( $@, qr/1 is not exist/, 'method not exist' );
}