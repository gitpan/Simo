package Simo;
use strict;
use warnings;
use Carp;

our $VERSION = '0.05_01';

sub import{
    my $caller_pkg = caller;
    
    {
        # export function
        no strict 'refs';
        *{ "${caller_pkg}::ac" } = \&Simo::ac;
        
        # caller inherit Simo
        push @{ "${caller_pkg}::ISA" }, __PACKAGE__;
    }

    # auto strict and warnings
    strict->import;
    warnings->import;
}

sub new{
    my ( $proto, @args ) = @_;
    
    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    croak 'key-value pairs must be passed to new method' if @args % 2;
    
    # bless
    my $self = {};
    my $pkg = ref $proto || $proto;
    bless $self, $pkg;
    
    # set args
    while( my ( $attr, $val ) = splice( @args, 0, 2 ) ){
        croak "Invalid key '$attr' is passed to ${pkg}::new" unless $self->can( $attr );
        no strict 'refs';
        $self->$attr( $val );
    }
    return $self;
}

# accessor option
our $AC_OPT = {};
our %VALID_AC_OPT = map{ $_ => 1 } qw( default constrain filter trigger set_hook get_hook hash_force );

# register accessor
sub ac(@){

    # accessor info
    my ( $self, $attr, $pkg, @vals ) = _SIMO_get_ac_info();
    
    # check and rearrange accessor option;
    my $ac_opt = {};
    
    $ac_opt->{ default } = shift if @_ % 2;
    my $hook_options_exist = {};
    
    while( my( $key, $val ) = splice( @_, 0, 2 ) ){
        croak "$key of ${pkg}::$attr is invalid accessor option" 
            unless $VALID_AC_OPT{ $key };
        
        carp "${pkg}::$attr : $@" 
            unless _SIMO_check_hook_options_order( $key, $hook_options_exist );
        
        $ac_opt->{ $key } = $val;
    }
    
    # register accessor option
    $AC_OPT->{ $pkg }{ $attr } = $ac_opt;

    # create accessor
    {
        no strict 'refs';
        no warnings 'redefine';
        *{ "${pkg}::$attr" } = eval _SIMO_create_accessor( $pkg, $attr );;
    }
    
    # call accessor
    $self->$attr( @vals );
}

# check hook option order ( constrain, filter, and trigger )
our %VALID_HOOK_OPT = ( constrain => 1, filter => 2, trigger => 3 );

sub _SIMO_check_hook_options_order{
    my ( $key, $hook_options_exist ) = @_;
    
    return 1 unless $VALID_HOOK_OPT{ $key };
    
    foreach my $hook_option_exist ( keys %{ $hook_options_exist } ){
        if( $VALID_HOOK_OPT{ $key } < $VALID_HOOK_OPT{ $hook_option_exist } ){
            $@ = "$key option should be appear before $hook_option_exist option";
            return 0;
        }
    }
    $hook_options_exist->{ $key } = 1;
    return 1;
}

# create accessor.
sub _SIMO_create_accessor{
    my ( $pkg, $attr ) = @_;
    
    my $e =
        qq/sub{\n/ .
        # arg recieve
        qq/    my ( \$self, \@vals ) = \@_;\n\n/;
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ default } ){
        # default value
        $e .=
        qq/    if( ! exists( \$self->{ $attr } ) ){\n/ .
        qq/        \$self->{ $attr } = \$AC_OPT->{ $pkg }{ $attr }{ default };\n/ .
        qq/    }\n/ .
        qq/    \n/;
    }
    
    # get value
    $e .=
        qq/    my \$ret = \$self->{ $attr };\n\n/;
    
    $e .=
        qq/    if( \@vals ){\n/ .
    
    # rearrange value
        qq/        my \$val = \@vals == 1 ? \$vals[0] :\n/;
    $e .= $AC_OPT->{ $pkg }{ $attr }{ hash_force } ?
        qq/                   \@vals >= 2 ? { \@vals } :\n/ :
        qq/                   \@vals >= 2 ? [ \@vals ] :\n/;
    $e .=
        qq/                   undef;\n\n/;
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ set_hook } ){
        # set_hook option
        $e .=
        qq/        eval{ \$val = \$AC_OPT->{ $pkg }{ $attr }{ set_hook }->( \$self, \$val ) };\n/ .
        qq/        Carp::confess( \$@ ) if \$@;\n\n/;
    }
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ constrain } ){
        # constrain option
        $e .=
        qq/        my \$constrains = \$AC_OPT->{ $pkg }{ $attr }{ constrain };\n/ .
        qq/        \$constrains = [ \$constrains ] unless ref \$constrains eq 'ARRAY';\n/ .
        qq/        foreach my \$constrain (\@{ \$constrains } ){\n/ .
        qq/            Carp::croak( "constrain of ${pkg}::$attr must be code ref" )\n/ .
        qq/                unless ref \$constrain eq 'CODE';\n/ .
        qq/            \n/ .
        qq/            local \$_ = \$val;\n/ .
        qq/            my \$ret = \$constrain->( \$val );\n/ .
        qq/            Carp::croak( "Illegal value \$val is passed to ${pkg}::$attr" )\n/ .
        qq/                unless \$ret;\n/ .
        qq/        }\n\n/;
    }
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ filter } ){
        # filter option
        $e .=
        qq/        if( my \$filters = \$AC_OPT->{ $pkg }{ $attr }{ filter } ){\n/ .
        qq/            \$filters = [ \$filters ] unless ref \$filters eq 'ARRAY';\n/ .
        qq/            foreach my \$filter ( \@{ \$filters } ){\n/ .
        qq/                Carp::croak( "filter of ${pkg}::$attr must be code ref" )\n/ .
        qq/                    unless ref \$filter eq 'CODE';\n/ .
        qq/                \n/ .
        qq/                local \$_ = \$val;\n/ .
        qq/                \$val = \$filter->( \$val );\n/ .
        qq/            }\n/ .
        qq/        }\n\n/;
    }
    
    # set value
    $e .=
        qq/        \$self->{ $attr } = \$val;\n\n/;
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ trigger } ){
        # trigger option
        $e .=
        qq/        if( my \$triggers = \$AC_OPT->{ $pkg }{ $attr }{ trigger } ){\n/ .
        qq/            \$triggers = [ \$triggers ] unless ref \$triggers eq 'ARRAY';\n/ .
        qq/            foreach my \$trigger ( \@{ \$triggers } ){\n/ .
        qq/                Carp::croak( "trigger of ${pkg}::$attr must be code ref" )\n/ .
        qq/                    unless ref \$trigger eq 'CODE';\n/ .
        qq/                \n/.
        qq/                local \$_ = \$self;\n/ .
        qq/                \$trigger->( \$self );\n/ .
        qq/            }\n/ .
        qq/        }\n/;
    }
    
    $e .=
        qq/    }\n/;
    
    if( defined $AC_OPT->{ $pkg }{ $attr }{ get_hook } ){
        # get_hook option
        $e .=
        qq/    else{\n/ .
        qq/        eval{ \$ret = \$AC_OPT->{ $pkg }{ $attr }{ get_hook }->( \$self, \$ret ) };\n/ .
        qq/        Carp::confess( \$@ ) if \$@;\n/ .
        qq/    };\n/;
    }
    
    #return
    $e .=
        qq/    return \$ret;\n/ .
        qq/}\n/;
    
    return $e;
}

# Helper to get acsessor info;
sub _SIMO_get_ac_info {
    package DB;
    my @caller = caller 2;
    
    my ( $self, @vals ) = @DB::args;
    my $sub = $caller[ 3 ];
    my ( $pkg, $attr ) = $sub =~ /^(.*)::(.+)$/;

    return ( $self, $attr, $pkg, @vals );
}

=head1 NAME

Simo - Very simple framework for Object Oriented Perl.

=head1 VERSION

Version 0.05_01

=cut

=head1 FEATURES

Simo is framework that simplify Object Oriented Perl.

The feature is that

=over 4

=item 1. You can define accessors in very simple way.

=item 2. Overridable new method is prepared.

=item 3. You can define default value of attribute.

=item 4. Simo is very small. so You can install and excute it very fast.

=back

If you use Simo, you are free from bitter work 
writing new and accessors repeatedly.

=cut

=head1 SYNOPSIS

=head2 Define class and accessors.

    package Book;
    use Simo;
    
    # define accessors
    sub title{ ac }
    
    # define default value
    sub author{ ac default => 'Kimoto' }
    
    # define constrain subroutine
    sub price{ ac constrain => sub{ /^\d+$/ } } # price must be integer.

    # define filter subroutine
    sub description{ ac filter => sub{ uc } } # convert to upper case.

    # define trigger subroutine
    sub issue_datetime{ ac trigger => \&update_issue_date }
    sub issue_date{ ac } # if issue_datetime is updated, issue_date is updated.
    
    sub update_issue_date{
        my $self = shift;
        my $date = substr( $self->issue_datetime, 0, 10 );
        $self->issue_date( $date );
    }
    1;
=cut

=head2 Using class and accessors

    use strict;
    use warnings;
    use Book;

    # create object
    my $book = Book->new( title => 'OO tutorial' );

    # get attribute
    my $author = $book->author;

    # set attribute
    $book->author( 'Ken' );

    # constrain( If try to set illegal value, this call will die )
    $book->price( 'a' ); 

    # filter ( convert to 'IT IS USEFUL' )
    $book->description( 'It is useful' );

    # trigger( issue_date is updated '2009-01-01' )
    $book->issue_datetime( '2009-01-01 12:33:45' );
    my $issue_date = $book->issue_date;

=cut

=head1 DESCRIPTION

=head2 Define class and accessors

You can define class and accessors in simple way.

new method is automatically created, and title accessor is defined.

    package Book;
    use Simo;

    sub title{ ac }
    1;

=cut

=head2 Using class and accessors

You can pass key-value pairs to new, and can get and set value.

    use Book;
    
    # create object
    my $book = Book->new(
        title => 'OO tutorial',
    );
    
    # get value
    my $title = $book->title;
    
    # set value
    $book->title( 'The simplest OO' );

=cut

=head2 Automatically array convert

If you pass array to accessor, array convert to array ref.

    $book->title( 'a', 'b' );
    $book->title; # get [ 'a', 'b' ], not ( 'a', 'b' )

=cut

=head2 Accessor options

=head3 default option

You can define default value of attribute.

    sub title{ ac default => 'Perl is very interesting' }

=cut

=head3 constrain option

you can constrain setting value.

    sub price{ ac constrain => sub{ /^\d+$/ } }

For example, If you call $book->price( 'a' ), this call is die, because 'a' is not number.

'a' is set to $_. so if you can use regular expression, omit $_.

you can write not omiting $_.

    sub price{ ac constrain => sub{ $_ > 0 && $_ < 3 } }

If you display your message when program is die, you call craok.
    
    use Carp;
    sub price{ ac constrain => sub{ $_ > 0 && $_ < 3 or croak "Illegal value" } }

and 'a' is alse set to first argument. So you can receive 'a' as first argument.

   sub price{ ac constrain => \&_is_number }
   
   sub _is_number{
       my $val = shift;
       return $val =~ /^\d+$/;
   }

and you can define more than one constrain.

    sub price{ ac constrain => [ \&_is_number, \&_is_non_zero ] }

=cut

=head3 filter option

you can filter setting value.

    sub description{ ac filter => sub{ uc } }

setting value is $_ and frist argument like constrain.

and you can define more than one filter.

    sub description{ ac filter => [ \&uc, \&quoute ] }

=cut

=head3 trigger option

You can define subroutine called after value is set.

For example, issue_datetime is set, issue_date is update.

$self is set to $_ and $_[0] different from constrain and filter.

    sub issue_datetime{ ac trigger => \&update_issue_date }
    sub issue_date{ ac }
    
    sub update_issue_date{
        my $self = shift;
        my $date = substr( $self->issue_datetime, 0, 10 );
        $self->issue_date( $date );
    }

and you can define more than one trigger.

    sub issue_datetime{ ac trigger => [ \&update_issue_date, \&update_issue_time ] }

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

=head3 set_hook option

set_hook option is now not recommended. this option will be deleted in future 2019/01/01

=cut

=head3 get_hook option

get_hook option is now not recommended. this option will be deleted in future 2019/01/01

=cut

=head2 Order of constrain, filter and trigger

=over 4

=item 1. val is passed to constrain subroutine.

=item 2. val is passed to filter subroutine.

=item 3. val is set

=item 4. trigger subroutine is called

=back

       |---------|   |------|                  |-------| 
       |         |   |      |                  |       | 
 val-->|constrain|-->|filter|-->(val is set)-->|trigger| 
       |         |   |      |                  |       | 
       |---------|   |------|                  |-------| 

=cut

=head2 Get old value

You can get old value when you use accessor as setter.

    $book->author( 'Ken' );
    my $old_value = $book->author( 'Taro' ); # $old_value is 'Ken'

=cut

=head1 FUNCTIONS

=head2 ac

ac is exported. This is used by define accessor. 

=cut

=head2 new

orveridable new method.

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

=cut

=head1 CAUTION

set_hook and get_hook option is now not recomended. these option will be deleted in future 2019/01/01

and non named defalut value definition is not recommended. this expression cannot be available in future 2019/01/01

    sub title{ ac 'OO tutorial' } # not recommend. cannot be available in future.

=cut

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
