use strict;
use warnings;

use Test::More 'no_plan';


{
    my $book = Data::Book->new;
    
    is_deeply( [ sort $book->ATTRS ], [ sort ( qw( a b c ) ) ], 'attr list' );
    
    
    my $magazine = Data::Magazine->new;
    is_deeply( [ sort $magazine->ATTRS ], [ sort ( qw( d e f ) ) ], 'attr list extend' );
}

package Data::Book;
use Simo;

sub title : Attr { ac default => 1 }
sub author : Attr { ac default => 2 }

sub ATTRS{ qw/a b c / }

package Data::Magazine;
use Simo( base => 'Data::Book' );

sub price : Attr { ac default => 3 }

sub ATTRS{ qw/d e f / }
