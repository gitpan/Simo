use Test::More 'no_plan';
use strict;
use warnings;

package T1;
use Simo;

# constrain
# fitler
# trigger

sub a{ ac 
    constrain => sub{},
    filter => sub{},
    trigger => sub{}
}

sub b{ ac
    filter => sub{},
    constrain => sub{}
}
sub c{ ac
    trigger => sub{},
    filter => sub{}
}

sub d{ ac
    trigger => sub{},
    constrain => sub{},
}

package main;

{
    my $t = T1->new;
    {
        my $warn;
        $SIG{__WARN__} = sub{
            $warn = shift;
        };
        $t->a;
        ok( !$warn, 'option order success pattern' );
    }
    
    {
        my $warn;
        $SIG{__WARN__} = sub{
            $warn = shift;
        };
        $t->b;
        like( $warn, qr/T1::b : constrain option should be appear before filter option/, 'option order success pattern' );
    }

    {
        my $warn;
        $SIG{__WARN__} = sub{
            $warn = shift;
        };
        $t->c;
        like( $warn, qr/T1::c : filter option should be appear before trigger option/, 'option order success pattern' );
    }

    {
        my $warn;
        $SIG{__WARN__} = sub{
            $warn = shift;
        };
        $t->d;
        like( $warn, qr/T1::d : constrain option should be appear before trigger option/, 'option order success pattern' );
    }
}
