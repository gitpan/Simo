use strict;
use warnings;
use Test::More qw( no_plan );


package Book;
use Simo;

sub title{ ac 1 }

package PBook;
use base qw( Book );


package main;
use strict;
use warnings;

my $book = Book->new;
my $pbook = PBook->new;

$pbook->title;
is( $book->title, 1, 'method invoked atfter super class dose' );





__END__