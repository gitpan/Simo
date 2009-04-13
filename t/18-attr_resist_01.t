use strict;
use warnings;

use Test::More 'no_plan';


{
    my $book = Data::Book->new;
    
    is_deeply( [ sort $book->ATTRS ], [ sort ( 'title', 'author' ) ], 'attr list' );
    is_deeply( [ sort Data::Book->ATTRS ], [ sort ( 'title', 'author' ) ], 'attr list pacakge' );
    
    
    my $magazine = Data::Magazine->new;
    is_deeply( [ sort $magazine->ATTRS ], [ sort ( 'title', 'author', 'price' ) ], 'attr list extend' );
    is_deeply( [ sort Data::Magazine->ATTRS ], [ sort ( 'title', 'author', 'price' ) ], 'attr list extend package' );
    
    eval"package Data::Paper;" .
        "use Simo;" .
        "sub aaa : Attr{ ac };" .
        "sub iii : Attr{ ac };";
    is_deeply( [ sort Data::Paper->ATTRS ], [ sort ( qw/aaa iii/ ) ], 'attr list dinamically extend' );

    eval"package Data::Mop;" .
        "use Simo;" .
        "sub aaa { ac };" .
        "sub iii { ac };";
    is_deeply( [ sort Data::Mop->ATTRS ], [], 'attr list no regist extend' );
    
    eval"package Data::Cap;" .
        "use Simo;" .
        "sub aaa : Attr { ac };" .
        "sub iii : Attr { ac };";
        
    eval"package Data::Yap;" .
        "use Simo;" .
        "sub aaa  { ac };" .
        "sub iii  { ac };";
    is_deeply( [ sort Data::Yap->ATTRS ], [], 'attr list no regist extend' );
    is_deeply( [ sort Data::Cap->ATTRS ], [ sort ( qw/aaa iii/ )], 'attr list no regist extend' );
}

package Data::Book;
use Simo;

sub title : Attr { ac default => 1 }
sub author : Attr { ac default => 2 }


package Data::Magazine;
use Simo( base => 'Data::Book' );

sub price : Attr { ac default => 3 }

