package Simo;
use strict;
use warnings;
use Carp;

our $VERSION = '0.03_06';

our $ac_opt = {};
our $ac_define_class = {};

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
    my ( $proto, @args ) = @_;
    
    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    croak 'key-value pairs must be passed to new method' if @args % 2;
    
    # bless
    my $self = {};
    my $class = ref $proto || $proto;
    bless $self, $class;
    
    # set args
    while( my ( $attr, $val ) = splice( @args, 0, 2 ) ){
        croak "Invalid key '$attr' is passed to ${class}::new" unless $self->can( $attr );
        no strict 'refs';
        $self->$attr( $val );
    }
    return $self;
}

# Accessor register
sub ac(@){

    # accessor info
    my ( $self, $attr, $ac_define_class, @vals ) = _SIMO_get_ac_info();
    
    # check accessor info
    my $class = ref $self;
    
    # check and rearrange accessor option;
    my $ac_opt = {};
    my %valid_opt = map{ $_ => 1 } qw( default constrain filter trigger set_hook get_hook hash_force );
        
    $ac_opt->{ default } = shift if @_ % 2;
    
    while( my( $key, $val ) = splice( @_, 0, 2 ) ){
        croak "$key of ${ac_define_class}::$attr is invalid accessor option" unless $valid_opt{ $key };
        $ac_opt->{ $key } = $val;
    }
    
    # register accessor option
    $Simo::ac_opt{ $ac_define_class }{ $attr } = $ac_opt;

    # redefine real acessor
    my $ac_redefine = qq/sub ${ac_define_class}::$attr { _SIMO_ac_real( '$attr' , \@_ ) }/;
    
    {
        no warnings 'redefine';
        eval $ac_redefine;
    }
    
    # call accessor
    $self->$attr( @vals );
}

# Real accessor.
sub _SIMO_ac_real{
    my ( $attr, $self, @vals ) = @_;
    
    # check args
    my $class = ref $self;
    croak "$attr must be called from object." unless $class;
    
    # get accessor defined class
    $Simo::ac_define_class->{ $class }{ $attr } ||= _SIMO_get_ac_define_class( $class, $attr );
    my $ac_define_class = $Simo::ac_define_class->{ $class }{ $attr };
    
    # get accessor option
    my $ac_opt = $Simo::ac_opt{ $ac_define_class }{ $attr };
    
    # init by default value
    $self->{ $attr } = $ac_opt->{ default } unless exists $self->{ $attr };
    
    # return value( return old_value in case setter is called )
    my $ret = $self->{ $attr };
    
    # set value if value is defined
    if( @vals ){
        # rearrange value;
        my $val = @vals == 1 ? $vals[0] :
                  @vals >= 2 && $ac_opt->{ hash_force } ? { @vals } :
                  @vals >= 2 ? [ @vals ] :
                  undef;
    
        # setter hook function
        # ( set_hook option is now not recommended. this option will be deleted in future 2019 )
        if( $ac_opt->{ set_hook } ){
            eval{ $val = $ac_opt->{ set_hook }->($self,$val) };
            confess $@ if $@;
        }
        
        # constrain
        if( my $constrains = $ac_opt->{ constrain } ){
            $constrains = [ $constrains ] unless ref $constrains eq 'ARRAY';
            foreach my $constrain ( @{ $constrains } ){
                croak "constrain of ${ac_define_class}::$attr must be code ref"
                    unless ref $constrain eq 'CODE';
                    
                local $_ = $val;
                my $ret = $constrain->( $val );
                croak "Illegal value $val is passed to ${ac_define_class}::$attr"
                    unless $ret;
            }
        }
        
        # filter
        if( my $filters = $ac_opt->{ filter } ){
            $filters = [ $filters ] unless ref $filters eq 'ARRAY';
            foreach my $filter ( @{ $filters } ){
                croak "filter of ${ac_define_class}::$attr must be code ref"
                    unless ref $filter eq 'CODE';
                                    
                local $_ = $val;
                $val = $filter->( $val );
            }
        }
        
        # set new value
        $self->{ $attr } = $val;
        
        # trigger
        if( my $triggers = $ac_opt->{ trigger } ){
            $triggers = [ $triggers ] unless ref $triggers eq 'ARRAY';
            foreach my $trigger ( @{ $triggers } ){
                croak "trigger of ${ac_define_class}::$attr must be code ref"
                    unless ref $trigger eq 'CODE';

                local $_ = $self;
                $trigger->( $self );
            }
        }
    }
    else{
        # getter hook function
        # ( get_hook option is now not recommended. this option will be deleted in future 2019 )
        if( $ac_opt->{ get_hook } ){
            eval{ $ret = $ac_opt->{ get_hook }->($self, $ret) };
            confess $@ if $@;
        }
    }
    return $ret;
}

# Get accessor define class
sub _SIMO_get_ac_define_class{
    my ( $class, $attr ) = @_;
    
    my $ac_define_class = ( caller 2 )[ 3 ];
    
    if( $ac_define_class =~ /^(.+)::/ ){
        $ac_define_class = $1;
    }
    return $ac_define_class;
}

# Helper to get acsessor info;
sub _SIMO_get_ac_info {
    package DB;
    my @caller = caller 2;
    
    my ( $self, @vals ) = @DB::args;
    my $sub = $caller[ 3 ];
    my ( $ac_define_class, $attr ) = $sub =~ /^(.*)::(.+)$/;

    return ( $self, $attr, $ac_define_class, @vals );
}

=head1 NAME

Simo - Very simple framework for Object Oriented Perl.

=head1 VERSION

Version 0.03_05

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

=head2 Using class and accessor

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

=head3 default option - define default value of attribute

You can define default value of attribute.

    sub title{ ac default => 'Perl is very interesting' }

=cut

=head3 constrain option - restrict illegal value is set

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

=head3 filter option - filter

you can filter setting value.

    sub description{ ac filter => sub{ uc } }

setting value is $_ and frist argument like constrain.

and you can define more than one filter.

    sub description{ ac filter => [ \&uc, \&quoute ] }

=cut

=head3 trigger option - subroutine called after value is set.

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

=head2 constrain, filter, trigger Image

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

=head2 COUTION

set_hook and get_hook option is not recomended. these option will be deleted in future 2019/01/01

and non named defalut value definition is not recommended. this expression cannot be used in future 2019/01/01

    sub title{ ac 'OO tutorial' } # not recommend. cannot be used in future.

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
