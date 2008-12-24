package Simo;
use strict;
use warnings;
use Carp;

our $VERSION = '0.02';

sub import{
    my $caller_class = caller;
    
    {
        # export function
        no strict 'refs';
        *{ "${caller_class}::ac" } = \&Simo::ac;
        
        # caller inherit Simo
        push @{ "${caller_class}::ISA" }, __PACKAGE__;
    }

    # auto strict and warnings
    strict->import;
    warnings->import;
}

sub new{
    my ( $class, @args ) = @_;
    
    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    confess 'please pass key value pairs to new method' if @args % 2;
    
    # bless
    my $self = {};
    bless $self, ref $class || $class;
    
    # set args
    while( my ( $key, $val ) = splice( @args, 0, 2 ) ){
        no strict 'refs';
        eval{ $self->$key( $val ) };
        croak $@ if $@;
    }
    return $self;
}

# Accessor register
sub ac(@){

    # accessor info
    my ( $self, $key, $ac_define_class, @vals ) = _SIMO_ac_info();
    
    # check accessor info
    my $class = ref $self;
    confess "Cannot call accessor from Class." unless $class;
    
    # check and rearrange accessor option;
    my $ac_opt = {};
    my %valid_opt = map{ $_ => 1 } qw( default set_hook get_hook hash_force );
        
    $ac_opt->{ default } = shift if @_ % 2;
    
    while( my( $key, $val ) = splice( @_, 0, 2 ) ){
        confess "$key is not valid accessor option" unless $valid_opt{ $key };
        $ac_opt->{ $key } = $val;
    }
    
    # register accessor option
    _SIMO_ac_opt( $ac_define_class, $key, $ac_opt );

    # redefine real acessor
    my $ac_redefine = qq/sub ${ac_define_class}::${key} { _SIMO_ac_real( '$key' , \@_ ) }/;
    
    {
        no warnings 'redefine';
        eval $ac_redefine;
    }
    
    # call accessor
    $self->$key( @vals );
}

# Real accessor.
sub _SIMO_ac_real{
    my ( $key, $self, @vals ) = @_;
    
    # check args
    my $class = ref $self;
    confess "Cannot call accessor from Class." unless $class;
    
    # get accessor defined class
    my $ac_define_class = _SIMO_ac_define_class( $class, $key );
    
    # get accessor option
    my $ac_opt = _SIMO_ac_opt( $ac_define_class, $key );
    
    # rearrange value;
    my $val = @vals == 1 ? $vals[0] :
              @vals >= 2 && $ac_opt->{ hash_force } ? { @vals } :
              @vals >= 2 ? [ @vals ] :
              undef;
    
    # return value( return old_value in case setter is called )
    my $ret = _SIMO_obj_updated($self,$key) ? $self->{$key} : $ac_opt->{default};
    
    # set value if value is defined
    if( defined( $val ) ){
        # setter hook function
        if( $ac_opt->{ set_hook } ){
            eval{ $val = $ac_opt->{ set_hook }->($self,$val) };
            confess $@ if $@;
        }
        
        # set new value
        $self->{ $key } = $val;
        
        # updated is true
        _SIMO_obj_updated( $self, $key, 1 );
    }
    else{
        # getter hook function
        if( $ac_opt->{ get_hook } ){
            eval{ $ret = $ac_opt->{ get_hook }->($self, $ret) };
            confess $@ if $@;
        }
    }
    
    return !wantarray ? $ret :
           ref $ret eq 'ARRAY' ? @{ $ret } :
           ref $ret eq 'HASH' ? %{ $ret } :
           ( $ret );
}

# Get accessor define class
sub _SIMO_ac_define_class{
    my ( $class, $key ) = @_;
    unless( $Simo::info{ class }{ $class }{ ac }{ $key }{ ac_define_class } ){
        
        my $ac_define_class = ( caller 2 )[ 3 ];
        
        if( $ac_define_class =~ /^(.+)::/ ){
            $ac_define_class = $1;
        }
        
        $Simo::info{ class }{ $class }{ ac }{ $key }{ ac_define_class } = $ac_define_class;
    }
    return $Simo::info{ class }{ $class }{ ac }{ $key }{ ac_define_class };
}

# Get and set accessor opt
sub _SIMO_ac_opt{
    my( $class, $key, $opt ) = @_;
    if( defined( $opt ) ){
        $Simo::info{ class }{ $class }{ ac }{ $key }{ opt } = $opt;
    }
    return $Simo::info{ class }{ $class }{ ac }{ $key }{ opt };
}

# Check whether default is updated.
sub _SIMO_obj_updated{
    my ( $self, $key, $val ) = @_;
    if( defined( $val ) ){
        $Simo::info{ obj }{ $self }{ ac }{ $key }{ updated } = $val;
    }
    return $Simo::info{ obj }{ $self }{ ac }{ $key }{ updated };
}

# Helper to get acsessor info;
sub _SIMO_ac_info {
    package DB;
    my @caller = caller 2;
    
    my ( $self, @vals ) = @DB::args;
    my $sub = $caller[ 3 ];
    my ( $ac_define_class, $key ) = $sub =~ /^(.*)::(.+)$/;

    return ( $self, $key, $ac_define_class, @vals );
}

# Simo object destroctor
sub DESTROY{
    my $self = shift;
    delete $Simo::info{ obj }{ $self };
}

=head1 NAME

Simo - Very simple framework for Object Oriented Perl.

=head1 VERSION

Version 0.01

=cut

=head1 FEATURES

Simo is framework that simplify Object Oriented Perl.

The feature is that

=over 4

=item 1.You can write accessors in very simple way.

=item 2.Inheritable new method is prepared.

=item 3.You can set default value and hook function for accessors

=back

If You use Simo, you are free from bitter work 
writing new and accessors repeatedly

=cut

=head1 SYNOPSIS

    package Book;
    use Simo;
    
    # simple accessors
    sub title{ ac }
    
    # having default value
    sub author{ ac 'Kimoto' }
    
    # all accessor option 
    sub description{ ac
        default => 'This is good book',
        set_hook => sub{
            my ( $self, $val ) = @_;
            # do what you want to do
            return $val;
        },
        get_hook => sub{
            my ( $self, $val ) = @_;
            # do what you want to do
            return $val;
        },
        hash_force => 1
    }
    1;

=head1 DESCRIPTION

=head2 Creating class and accessors

You can create class and accessors.

    package Book;
    use Simo;
    
    # accessors
    sub title{ ac }
    sub author{ ac }
    sub description{ ac }
    1;

This sample create Book class and three accessor mothods( title,author and description ),
and new method is automatically created.

=cut

=head2 Using class and accessors

You can use Book class.
    use Book;
    
    # constructor
    my $book = Book->new(
        title => 'Happy book',
        author => 'Ken',
        description => 'this give you happy',
    );
    
    # get value
    my $title = $book->title; # 'Happy book'
    
    # set value
    $book->author( 'Taro' );

You can pass key-value pairs to new method. Key is need to be same name as accessor.

If you pass nonexistent key, script will die.

you can get value :

    $book->title;

you can set value :

    $book->title( 'Taro' );
    
=head2 Get old value

You can get old value when you use accessor as setter.

    $book->author( 'Ken' );
    my $old_value = $book->author( 'Taro' ); # $old_value is 'Ken'

=head2 accessor having Default value

You can set default value for accessor.

    package Book;
    use Simo;

    sub title{ ac 'Papa' }
    
You get 'Papa' if 'title' field is not initialized.

=cut

=head2 Setter Hook function for validation or filter or etc.

You can set set_hook function for accessor.

    package Book;
    use Simo;
    
    # set_hook function for accessor
    sub date{ ac set_hook => \&date_filter }
    
    # set_hook function definition
    sub date_filter{
        my ( $self, $val ) = @_;
        $val =~ s/-//g; # ( '2008-10-10' -> '20081010' )
        return $val;
    }
    1;

If you set date this way
    $book->title( '2008-08-11' );
    
'2008-08-08' is filtered, and change to '20080811'.

=cut

=head2 set_hook function arguments and return value

set_hook function receive two args( $self and $val ).

In this example, $self is $book object.

$val is passed value '2008-08-11'

if you pass array to setter, $val has been converted to array ref.

and you must return scalar, not list. 

=cut

=head2 Getter Hook function for initialization or etc.

You can set get_hook function for accessor.

    package Book;
    use Simo;
    
    # get_hook function for accessor
    sub date{ ac
        get_hook => sub{
            my ( $self, $val ) = @_;
            if( !$val ){ # val is $self->{ 'conf' }
                
                $val = localtime;
                
                $self->date( $val ); # if you set 
            }
            return $val;
        }
    }

    1;

you get date

    $book->date;

if $book->{ 'date' } is undef, $book->date return current localtime.

get_hook option is useful, if you want to set default value in dynamically, not Statically.

=cut

=head2 get_hook function arguments and return value

get_hook function receive two args( $self and $val ).

In this example, $self is $book object.

$val is current value undef.

and you must return scalar, not list. 

=cut

=head2 Automatically type convert

If you pass array to accessor, array convert to array ref.
    $book->title( 'a', 'b' );
    $book->title; # get [ 'a', 'b' ], not ( 'a', 'b' )

=cut

=head2 Accessor option

You can set accessor option.

=head3 default option

You can set default value for accessor.

    sub author{ ac 'Kimoto' }

or explicitely

    sub author{ ac default => 'Kimoto' }

=cut

=head3 set_hook option

You can define hook function for setter

    sub date{ ac set_hook => \&filter }
    
    sub filter{
        my ( $self, $val ) = @_;
        # ...
        return $some_val;
    }
    
or using anonymous function

    sub data{ ac 
        set_hook => sub{
            my( $self, $val ) = @_;
            # ...
            return $some_val;
        }
    }

=cut

=head3 get_hook option

You can define hook function for getter

    sub date{ ac
        get_hook => sub{
            my ( $self, $val ) = @_;
            if( !$val ){ # val is $self->{ 'conf' }
                
                $val = localtime;
                
                $self->date( $val ); # if you set 
            }
            return $val;
        }
    }
=cut

=head3 hash_force option

If you pass array to accessor, Normally list convert to array ref.
    $book->title( 'a' , 'b' ); # convert to [ 'a', 'b' ]

Even if you write
    $book->title( a => 'b' )

( a => 'b' ) converted to [ 'a', 'b' ] 

If you use hash_force option, you convert list to hash ref

    sub country_id{ ac hash_force => 1 }

    $book->title( a => 'b' ); # convert to { a => 'b' }

=cut

=head2 Multiple accessor option setting sample

    # one line
    sub title{ ac 'Pure love', hook => \&filter, hash_force => 1 }
    
    sub filter{
        # ..
    }
    
    # multiple line, hook function is anonimous
    sub title{ ac { k => 1 },
        hash_force => 1,
        hook => sub {
            # ..
        }
    }    
    
    # multiple line, default is explicitely, hook function is anonimous
    sub title{ ac
        default => { k => 1 },
        hash_force => 1,
        hook => sub {
            # ..
        }
    }

=cut

=head2 scalar context and list context

You can call accessor in scalar context and list context.

Accessor is designed to suit context.

You call accessor in scalar context, you get scalar value( scalar, array ref, hash ref, object, etc )

    my $ary = $book->authors; # you get array ref

You calls accessor in list context, you get list.

    my @ary = $book->authors; # you get list

=cut

=head1 EXPORT

This class exports ac function. you can use ac function to implement accessor. 

=head1 FUNCTIONS

=head2 ac

You can define accsessor using ac function.

    package Book;
    use Simo;
    
    sub title{ ac }
    ...

You can use this accessor.

Get is
    $book->title;

Set is 
    $book->title( 'Bird Adventure' );

=cut

=head2 new

New method is created automatically.
it receive key-value pairs as args.

    my $book = Book->new( title => 'PaPa is good', author => 'MaMa' );

=cut

=head1 MORE TECHNIQUES

I teach you useful techniques.

=head2 New method overriding

by default, new method receive key-value pairs.
But you can change this action by overriding new method.

For example, Point class. You want to call new method this way.

    my $point = Point->new( 3, 5 ); # xPos and yPos

You can override new method.
    
    package Point;
    use Simo;

    sub new{
        my ( $self, $x, $y ) = @_; # two arg( not key-value pairs )
        
        # You can do anything if you need
        
        return $self->SUPER::new( x => $x, y => $y );
    }

    sub x{ ac }
    sub y{ ac }
    1;

Simo implement inheritable new method.
Whenever You change argments or add initializetion,
You override new method.

=cut

=head2 Extend base class

you may want to extend base class. It is OK.

But I should say to you that there are one thing you should know.
The order of Inheritance is very important.

I write good sample and bad sample.

    # base class
    package Book;
    sub title{ ac };
    
    # Good sample.
    # inherit base class. It is OK!
    package Magazine;
    use base 'Book'; # use base is first
    use Simo;        # use Simo is second;
    
    # Bad sample
    package Magazine;
    use Simo;          # use Simo is first
    use base 'Book';   # use base is second

If you call new method in Good sample, you call Book::new method.
This is what you wanto to do.

If you call new method in Bad sample, you call Simo::new method. 
you will think why Book::new method is not called?

Maybe, You will be wrong sometime. So I recomend you the following writing.

    package Magazine; use base 'Book'; # package and base class
    use Simo;                          

It is like other language class Definition and I think looking is not bat.
and you are not likely to choose wrong order.

=head1 AUTHOR

Yuki Kimoto, C<< <kimoto.yuki at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-simo at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Simo>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Simo


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Simo>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Simo>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Simo>

=item * Search CPAN

L<http://search.cpan.org/dist/Simo/>

=back


=head1 SEE ALSO

L<Class::Accessor>,L<Class::Accessor::Fast>, L<Moose>, L<Mouse>.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Yuki Kimoto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Simo
