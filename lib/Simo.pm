package Simo;
use strict;
use warnings;
use Carp;

our $VERSION = '0.07_03';

my %VALID_IMPORT_OPT = map{ $_ => 1 } qw( base mixin );
sub import{
    my ( $self, @opts ) = @_;
    @opts = %{ $opts[0] } if ref $opts[0] eq 'HASH';
    
    # import option
    my $import_opt = {};
    while( my ( $opt, $val ) = splice( @opts, 0, 2 ) ){
        croak "Invalid import option '$opt'" unless $VALID_IMPORT_OPT{ $opt };
        $import_opt->{ $opt } = $val;
    }
    
    my $caller_pkg = caller;
    
    # export function
    {
        # export function
        no strict 'refs';
        *{ "${caller_pkg}::ac" } = \&Simo::ac;
    }
    
    # inherit base class
    my @inherit_classes = _SIMO_get_inherit_classes( $import_opt );
    if( @inherit_classes ){
        eval "package $caller_pkg;" .
             "use base \@inherit_classes;";
        if( $@ ){ $@ =~ s/\s+at .+$//; croak $@ }
    }
    
    # inherit Simo
    {
        no strict 'refs';
        push @{ "${caller_pkg}::ISA" }, 'Simo';
    }

    # auto strict and warnings
    strict->import;
    warnings->import;
}

sub _SIMO_get_inherit_classes{
    my $import_opt = shift;
    my @base_classes;
    
    my @inherit_classes;
    if( my $base = $import_opt->{ base } ){
        push @inherit_classes,
            ref $base eq 'ARRAY' ? @{ $base } : $base;
    }
    
    if( my $mixin = $import_opt->{ mixin } ){
        push @inherit_classes,
            ref $mixin eq 'ARRAY' ? @{ $mixin } : $mixin;
    }
    
    foreach my $inherit_class( @inherit_classes ){
        croak "Invalid class name '$inherit_class'" unless $inherit_class =~ /^(\w+::)*\w+$/;
    }
    return @inherit_classes;
}

sub new{
    my ( $proto, @args ) = @_;

    # bless
    my $self = {};
    my $pkg = ref $proto || $proto;
    bless $self, $pkg;
    
    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    croak 'key-value pairs must be passed to new' if @args % 2;
    
    # set args
    while( my ( $attr, $val ) = splice( @args, 0, 2 ) ){
        croak "Invalid key '$attr' is passed to new" unless $self->can( $attr );
        no strict 'refs';
        $self->$attr( $val );
    }
    return $self;
}

# get value specify attr names
sub get_attrs{
    my ( $self, @attrs ) = @_;
    
    @attrs = @{ $attrs[0] } if ref $attrs[0] eq 'ARRAY';
    
    my @vals;
    foreach my $attr ( @attrs ){
        croak "Invalid key '$attr' is passed to get_attrs" unless $self->can( $attr );
        my $val = $self->$attr;
        push @vals, $val;
    }
    wantarray ? @vals : $vals[0];
}

# get value as hash specify attr names
sub get_attrs_as_hash{
    my ( $self, @attrs ) = @_;
    my @vals = $self->get_attrs( @attrs );
    
    my %attrs;
    @attrs{ @attrs } = @vals;
    
    wantarray ? %attrs : \%attrs;
}

# set values
sub set_attrs{
    my ( $self, @args ) = @_;

    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    croak 'key-value pairs must be passed to set_attrs' if @args % 2;
    
    # set args
    while( my ( $attr, $val ) = splice( @args, 0, 2 ) ){
        croak "Invalid key '$attr' is passed to set_attrs" unless $self->can( $attr );
        no strict 'refs';
        $self->$attr( $val );
    }
    return $self;
}

# run methods
sub run_methods{
    my ( $self, @method_or_args_list ) = @_;
    
    my $method_infos = $self->_SIMO_parse_run_methods_args( @method_or_args_list );
    while( my $method_info = shift @{ $method_infos } ){
        my ( $method, $args ) = @{ $method_info }{ qw( name args ) };
        
        if( @{ $method_infos } ){
            $self->$method( @{ $args } );
        }
        else{
            return wantarray ? ( $self->$method( @{ $args } ) ) :
                                 $self->$method( @{ $args } );
        }
    }
}

sub _SIMO_parse_run_methods_args{
    my ( $self, @method_or_args_list ) = @_;
    
    my $method_infos = [];
    while( my $method_or_args = shift @method_or_args_list ){
        croak "$method_or_args is bad. Method name must be string and args must be array ref"
            if ref $method_or_args;
        
        my $method = $method_or_args;
        croak "$method is not exist" unless $self->can( $method );
        
        my $method_info = {};
        $method_info->{ name } = $method;
        $method_info->{ args } = ref $method_or_args_list[0] eq 'ARRAY' ?
                                 shift @method_or_args_list :
                                 [];
        
        push @{ $method_infos }, $method_info;
    }
    return $method_infos;
}


# create accessor
sub ac(@){
    # Simo process
    my ( $self, $attr, @vals ) = _SIMO_process( @_ );
    
    # call accessor
    $self->$attr( @vals );
}

# accessor option
my %VALID_AC_OPT = map{ $_ => 1 } qw( default constrain filter trigger set_hook get_hook hash_force read_only );

# Simo process. register accessor option and create accessor.
sub _SIMO_process{
    # accessor info
    my ( $self, $attr, $pkg, @vals ) = _SIMO_get_ac_info();
    
    # check and rearrange accessor option;
    my $ac_opt = {};
    
    $ac_opt->{ default } = shift if @_ % 2; 
        # ( Unnamed default option is is now not recommended. this will be deleted in future 2019/01/01 )
    
    my $hook_options_exist = {};
    
    while( my( $key, $val ) = splice( @_, 0, 2 ) ){
        croak "$key of ${pkg}::$attr is invalid accessor option" 
            unless $VALID_AC_OPT{ $key };
        
        carp "${pkg}::$attr : $@" 
            unless _SIMO_check_hook_options_order( $key, $hook_options_exist );
        
        $ac_opt->{ $key } = $val;
    }
    

    # create accessor
    {
        my $code = _SIMO_create_accessor( $pkg, $attr, $ac_opt );
        no warnings qw( redefine closure );
        eval"sub ${pkg}::${attr} $code";
    }
    return ( $self, $attr, @vals );
}

# check hook option order ( constrain, filter, and trigger )
my %VALID_HOOK_OPT = ( constrain => 1, filter => 2, trigger => 3 );

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
    my ( $pkg, $attr, $ac_opt ) = @_;
    
    my $e =
        qq/{\n/ .
        # arg recieve
        qq/    my ( \$self, \@vals ) = \@_;\n\n/;
    
    if( defined $ac_opt->{ default } ){
        # default value
        $e .=
        qq/    if( ! exists( \$self->{ $attr } ) ){\n/ .
        qq/        \$self->{ $attr } = \$ac_opt->{ default };\n/ .
        qq/    }\n/ .
        qq/    \n/;
    }
    
    # get value
    $e .=
        qq/    my \$ret = \$self->{ $attr };\n\n/;

    if ( $ac_opt->{ read_only } ){
        $e .=
        qq/    Carp::croak( "${pkg}::$attr is read only" ) if \@vals;\n\n/;
        
        goto END_OF_VALUE_SETTING;
    }
        
    $e .=
        qq/    if( \@vals ){\n/ .
    
    # rearrange value
        qq/        my \$val = \@vals == 1 ? \$vals[0] :\n/;
    $e .= $ac_opt->{ hash_force } ?
        qq/                  \@vals >= 2 ? { \@vals } :\n/ :
        qq/                  \@vals >= 2 ? [ \@vals ] :\n/;
    $e .=
        qq/                  undef;\n\n/;
    
    if( defined $ac_opt->{ set_hook } ){
        # set_hook option
        #( set_hook option is is now not recommended. this option will be deleted in future 2019/01/01 )
        $e .=
        qq/        eval{ \$val = \$ac_opt->{ set_hook }->( \$self, \$val ) };\n/ .
        qq/        Carp::confess( \$@ ) if \$@;\n\n/;
    }
    
    if( defined $ac_opt->{ constrain } ){
        # constrain option

        $ac_opt->{ constrain } = [ $ac_opt->{ constrain } ] 
            unless ref $ac_opt->{ constrain } eq 'ARRAY';
        
        foreach my $constrain ( @{ $ac_opt->{ constrain } } ){
            Carp::croak( "constrain of ${pkg}::$attr must be code ref" )
                unless ref $constrain eq 'CODE';
        }
        
        $e .=
        qq/        foreach my \$constrain ( \@{ \$ac_opt->{ constrain } } ){\n/ .
        qq/            local \$_ = \$val;\n/ .
        qq/            \$@ = undef;\n/ .
        qq/            my \$ret = \$constrain->( \$val );\n/ .
        qq/            if( !\$ret ){\n/ .
        qq/                \$@ ||= 'must be valid value.';\n/ .
        qq/                Carp::croak( "${pkg}::$attr \$@" )\n/ .
        qq/            }\n/ .
        qq/        }\n\n/;
    }
    
    if( defined $ac_opt->{ filter } ){
        # filter option
        $ac_opt->{ filter } = [ $ac_opt->{ filter } ] 
            unless ref $ac_opt->{ filter } eq 'ARRAY';
        
        foreach my $filter ( @{ $ac_opt->{ filter } } ){
            Carp::croak( "filter of ${pkg}::$attr must be code ref" )
                unless ref $filter eq 'CODE';
        }
        
        $e .=
        qq/        foreach my \$filter ( \@{ \$ac_opt->{ filter } } ){\n/ .
        qq/            local \$_ = \$val;\n/ .
        qq/            \$val = \$filter->( \$val );\n/ .
        qq/        }\n\n/;
    }
    
    # set value
    $e .=
        qq/        \$self->{ $attr } = \$val;\n\n/;
    
    if( defined $ac_opt->{ trigger } ){
        $ac_opt->{ trigger } = [ $ac_opt->{ trigger } ]
            unless ref $ac_opt->{ trigger } eq 'ARRAY';
        
        foreach my $trigger ( @{ $ac_opt->{ trigger } } ){
            Carp::croak( "trigger of ${pkg}::$attr must be code ref" )
                unless ref $trigger eq 'CODE';
        }
        
        # trigger option
        $e .=
        qq/        foreach my \$trigger ( \@{ \$ac_opt->{ trigger } } ){\n/ .
        qq/            local \$_ = \$self;\n/ .
        qq/            \$trigger->( \$self );\n/ .
        qq/        }\n/;
    }
    
    $e .=
        qq/    }\n/;
    
    END_OF_VALUE_SETTING:
    
    if( defined $ac_opt->{ get_hook } ){
        # get_hook option
        # ( get_hook option is is now not recommended. this option will be deleted in future 2019/01/01 )
        $e .=
        qq/    eval{ \$ret = \$ac_opt->{ get_hook }->( \$self, \$ret ) };\n/ .
        qq/    Carp::confess( \$@ ) if \$@;\n/;
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
    my @caller = caller 3;
    
    my ( $self, @vals ) = @DB::args;
    my $sub = $caller[ 3 ];
    my ( $pkg, $attr ) = $sub =~ /^(.*)::(.+)$/;

    return ( $self, $attr, $pkg, @vals );
}

=head1 NAME

Simo - Very simple framework for Object Oriented Perl.

=head1 VERSION

Version 0.07_03

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
    
    # read only accessor
    sub get_size{ ac default => 5, read_only => 1 }
    
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
    
    # read only accessor
    $book->get_size;

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

=head3 read_only option

Read only accessor is defined

    sub get_size{ ac default => 5, read_only => 1 }

Accessor name should be contain 'get_'.If not, warnings is happen.

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

=head1 METHOD

=head2 new

orveridable new method.

=head2 get_attrs

    my( $title, $author ) = $book->get_attrs( 'title', 'author' );

=head2  get_attrs_as_hash

    my %hash = $book->get_attrs( 'title', 'author' );

or

    my $hash_ref = $book->get_attrs( 'title', 'author' );

=head2 set_attrs

    $book->set_attrs( title => 'Simple OO', author => 'kimoto' );

return value is $self. so method chaine is available

    $book->set_attrs( title => 'Simple OO', author => 'kimoto' )->some_method;
    
=head2 run_methods

this excute some methods continuously.

    my $result = $book_list->run_methods(
        'select' => [ type => 'Commic' ],
        'sort' => [ 'desc' },
        'get_result'
    );
    
args must be array ref. You can omit args.

You can get last method return value in scalar context or list context.

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
