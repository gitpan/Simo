use Test::More qw( no_plan );
use strict;
use warnings;

package Book;
use Simo;

sub title{ ac }

package main;
# ac from class 
{
    eval{
        Book->title;
    };
    
    like( $@,
        qr/Cannot call accessor from Class/,
        'accssor form class,not object'
    );
    
    my $book = Book->new( title => 1 );
    
    eval{
       Book->title;
    };
    
    like( $@,
        qr/Cannot call accessor from Class/,
        'accssor form class,not object'
    );    
}