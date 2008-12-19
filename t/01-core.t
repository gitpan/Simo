use Test::More qw( no_plan );

BEGIN{ use_ok( 'Simo' ) }
can_ok( 'Simo', qw( ac new ) ); 

package Book;
use Simo;

sub title{ ac }
sub author{ ac 'a' }
sub price{ ac
    default => 1,
    hook => sub{
        my( $self, $val ) = @_;
        return [ $val + 1, $self ];
    },
}

sub color{ ac
    hook => 1
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
    eval{
        my $book = Book->new( 'a' );
    };
    like( 
        $@, qr/please pass key value pairs to new method/,
        'not pass key value pair'
    );
}

{
    my $book = Book->new;
    eval{
        $book->new;
    };
    like(
        $@, qr/please call new method from class/,
        'not call new from class'
    )
}

{
    eval{
        my $book = Book->new( noexist => 1 );
    };
    like(
        $@, qr/noexist is invalid key/,
        'invalid key to new method'
    )
}

# set and get array and hash
{
    my $book = Book->new;
    $book->title( 1, 2 );
    
    my $ary_ref = $book->title;
    is_deeply( $ary_ref, [ 1, 2 ], 'set array and get array ref' );
    
    my @ary = $book->title;
    is_deeply( [ @ary ], [ 1, 2 ], 'set array and get arrya' );
    
    $book->title( { k => 1} );
    my $hash_ref = $book->title;
    is_deeply( $hash_ref, { k => 1}, 'set hash ref and get hash ref' );
    
    my %hash = $book->title;
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
    is( $val_default, 1, 'ac default option and hook' );
    
    $book->price( 2 );
    my ( $val_hook, $self_hook ) = $book->price;
    is( $val_hook, 3, 'ac hook option( val )' );
    is( ref $self_hook, 'Book', 'ac hook option( arg )' );
    
    eval{
        $book->color( 1 );
    };
    
    like( $@,
        qr/Please set valid code ref as hook/,
        'invalid hook',
    );
        
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
    my @ary_shallow = $book->title;
    push @ary_shallow, 3;
    is_deeply( [@ary_shallow],[1, 2, 3 ], 'shallow copy' );
    is_deeply( $ary_get, [1,2 ], 'shallow copy not effective' );
    
    push @{ $book->title }, 3;
    is_deeply( $ary_get, [ 1, 2, 3 ] );
    
}






