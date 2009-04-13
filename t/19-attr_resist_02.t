use strict;
use warnings;

use Test::More 'no_plan';

use lib 't/19-attr_resist_02/';

use Data::Book;
use Data::Magazine;


{
    my $book = Data::Book->new;
    
    is_deeply( [ sort $book->ATTRS ], [ sort ( 'title', 'author' ) ], 'attr list' );
    
    
    my $magazine = Data::Magazine->new;
    is_deeply( [ sort $magazine->ATTRS ], [ sort ( 'title', 'author', 'price' ) ], 'attr list extend' );
}
