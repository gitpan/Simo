use Test::More  tests => 31;

BEGIN{ use_ok( 'Simo' ) }
can_ok( 'Simo', qw( ac new ) ); 

package Book;
use Simo;

sub title{ ac }
sub author{ ac 'a' }

sub price{ ac
    default => 1,
    set_hook => sub{
        my( $self, $val ) = @_;
        return [ $val + 1, $self ];
    },
}

sub size{ ac
    get_hook => sub{
        my ( $self, $val ) = @_;
        return [ $val, $self ];
    }
}

sub color{ ac
    set_hook => 1,
    get_hook => 1
}

sub description{ ac
    hash_force => 1
}

sub raiting{ ac
    noexist => 1,
}

package main;

# new method
{
    my $book = Book->new;
    isa_ok( $book, 'Book', 'It is object' );
    isa_ok( $book, 'Simo', 'Inherit Simo' );
}

{
    my $book = Book->new( title => 'a', author => 'b' );
    
    is_deeply( 
        [ $book->title, $book->author ], [ 'a', 'b' ],
        'setter and getter and constructor' 
    );
}

{
    my $book = Book->new( { title => 'a', author => 'b' } );
    
    is_deeply( 
        [ $book->title, $book->author ], [ 'a', 'b' ],
        'setter and getter and constructor' 
    );
}

{
    eval{
        my $book = Book->new( 'a' );
    };
    like( 
        $@, qr/please pass key value pairs to new method/,
        'not pass key value pair'
    );
}

{
    eval{
        my $book = Book->new( noexist => 1 );
    };
    ok( $@, 'invalid key to new method' );
}

# set and get array and hash
{
    my $book = Book->new;
    $book->title( 1, 2 );
    
    my $ary_ref = $book->title;
    is_deeply( $ary_ref, [ 1, 2 ], 'set array and get array ref' );
    
    my @ary = $book->title;
    is_deeply( $ary[0], [ 1, 2 ], 'set array and get arrya' );
    
    $book->title( { k => 1} );
    my $hash_ref = $book->title;
    is_deeply( $hash_ref, { k => 1}, 'set hash ref and get hash ref' );
    
    my %hash =%{ $book->title };
    is_deeply( { %hash }, { k => 1 }, 'set hash ref and get hash' );
}

# setter return value
{
    my $book = Book->new;
    my $old_default = $book->author( 'b' );
    is( $old_default, 'a', 'return old value( default ) in case setter is called' );
    
    my $old = $book->author( 'c' );
    is( $old, 'b', 'return old value in case setter is called' );
}

# accessor option
{
    my $book = Book->new;
    my $val_default = $book->price;
    is( $val_default, 1, 'ac default option and set_hook' );
    
    $book->price( 2 );
    my ( $val_set_hook, $self_set_hook ) = @{ $book->price };
    is( $val_set_hook, 3, 'ac set_hook option( val )' );
    is( ref $self_set_hook, 'Book', 'ac set_hook option( arg )' );
    
    eval{
        $DB::single = 1;
        $book->color( 1 );
    };
    
    ok( $@, 'invalid set_hook' );
    
    
    $book->size( 2 );
    my ( $val_get_hook, $self_get_hook ) = @{ $book->size };
    is( $val_get_hook, 2, 'ac get_hook option( val )' );
    is( ref $self_get_hook, 'Book', 'ac get_hook option( arg )' );
    
    eval{
        $DB::single = 1;
        $book->color;
    };
    
    ok( $@, 'invalid get_hook' );

    
    $book->description( key => 1 );
    my $description = $book->description;
    is_deeply( $description, { key => 1 }, "ac hash_force option" );
    
    eval{
        $book->raiting;
    };
    like( $@,
        qr/noexist is not valid accessor option/,
        'no exist accessor option',
    );
}


# reference
{
    my $book = Book->new;
    my $ary = [ 1 ];
    $book->title( $ary );
    my $ary_get = $book->title;
    
    is( $ary, $ary_get, 'equel reference' );
    
    push @{ $ary }, 2;
    is_deeply( $ary_get, [ 1, 2 ], 'equal reference value' );
    
    # shallow copy
    my @ary_shallow = @{ $book->title };
    push @ary_shallow, 3;
    is_deeply( [@ary_shallow],[1, 2, 3 ], 'shallow copy' );
    is_deeply( $ary_get, [1,2 ], 'shallow copy not effective' );
    
    push @{ $book->title }, 3;
    is_deeply( $ary_get, [ 1, 2, 3 ] );
    
}

package Point;
use Simo;

sub x{ ac default => 1 }
sub y{ ac default => 1 }

package main;
# direct hash access
{
    my $p = Point->new;
    $p->{ x } = 2;
    is( $p->x, 2, 'default overwrited' );
    
    $p->x( 3 );
    is( $p->{ x }, 3, 'direct access' );
    
    is( $p->y, 1, 'defalut normal' );
}







