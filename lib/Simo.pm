package Simo;
use 5.008_001;
use strict;
use warnings;

use Carp;
use Simo::Error;
use Simo::Util qw( run_methods encode_attrs clone freeze thaw validate
                   new_and_validate new_from_objective_hash new_from_xml
                   get_hash get_values set_values encode_values decode_values
                   filter_values set_values_from_objective_hash
                   set_values_from_xml );

our $VERSION = '0.1201';

my %VALID_IMPORT_OPT = map{ $_ => 1 } qw( base new mixin );
sub import{
    my ( $self, @opts ) = @_;
    
    return unless $self eq 'Simo';
    
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
        *{ "${caller_pkg}::accessor" } = \&Simo::ac;
        *{ "${caller_pkg}::ac" } = \&Simo::ac;
        *{ "${caller_pkg}::and_super" } = \&Simo::and_super;
    }
    
    # caller package inherit these classes
    # 1.base class,  2.Simo,  3.mixin class
    
    _SIMO_inherit_classes( $caller_pkg, @{ $import_opt }{ qw( base new mixin ) } );
    
    # auto strict and warnings
    strict->import;
    warnings->import;
    
    # define MODIFY_CODE_ATTRIBUTES for caller package
    _SIMO_define_attributes_handler( $caller_pkg );
}

# callar package inherit some classes
sub _SIMO_inherit_classes{
    my ( $pkg, $base, $new, $mixin ) = @_;
    
    my @classes;
    
    if( $new ){
        push @classes,
            ref $new eq 'ARRAY' ? @{ $new } : $new;
    }
    
    if( $base ){
        push @classes,
            ref $base eq 'ARRAY' ? @{ $base } : $base;
    }
    
    push @classes, 'Simo';
    
    if( $mixin ){
        push @classes,
            ref $mixin eq 'ARRAY' ? @{ $mixin } : $mixin;
    }
    
    foreach my $class( @classes ){
        croak "Invalid class name '$class'" unless $class =~ /^(\w+::)*\w+$/;
    }
    
    eval "package $pkg;" .
         "use base \@classes;";
    if( $@ ){ $@ =~ s/\s+at .+$//; croak $@ }
}

sub _SIMO_define_attributes_handler{
    my $caller_pkg = shift;
    my $e .=
        qq/package ${caller_pkg};\n/ .
        qq/sub MODIFY_CODE_ATTRIBUTES {\n/ .
        qq/\n/ .
        qq/    my (\$pkg, \$ref, \@attrs) = \@_;\n/ .
        qq/    if( \$attrs[0] eq 'Attr' ){\n/ .
        qq/        push( \@Simo::ATTRIBUTES_CASHE, [\$pkg, \$ref ]);\n/ .
        qq/    }\n/ .
        qq/    else{\n/ .
        qq/        warn "'\$attrs[0]' is bad. attribute must be 'Attr'";\n/ .
        qq/    }\n/ .
        qq/    return;\n/ .
        qq/}\n/;
    
    eval $e;
    if( $@ ){ die "Cannot execute\n $e" }; # never occured.
}


sub new{
    my ( $proto, @args ) = @_;

    # bless
    my $self = {};
    my $pkg = ref $proto || $proto;
    bless $self, $pkg;
    
    # check args
    @args = %{ $args[0] } if ref $args[0] eq 'HASH';
    croak "key-value pairs must be passed to ${pkg}::new" if @args % 2;
    
    # set args
    while( my ( $attr, $val ) = splice( @args, 0, 2 ) ){
        unless( $self->can( $attr ) ){
            Simo::Error->throw(
                type => 'attr_not_exist',
                msg => "Invalid key '$attr' is passed to ${pkg}::new",
                pkg => $pkg,
                attr => $attr
            );
        }
        no strict 'refs';
        $self->$attr( $val );
    }
    
    foreach my $required_attrs ( $self->REQUIRED_ATTRS ){
        unless( exists $self->{ $required_attrs } ){
            Simo::Error->throw(
                type => 'attr_required',
                msg => "Attr '$required_attrs' is required.",
                pkg => $pkg,
                attr => $required_attrs
            );
        }
    }
    return $self;
}

sub new_self_and_parent{
    my $self = shift;
    my $class = ref $self || $self;
    
    my $parent_pkg = do{
        no strict 'refs';
        ${"${class}::ISA"}[0];
    };
    
    croak "Cannot call 'new_self_and_parent' from the class having no parent."
        if $parent_pkg eq 'Simo';
    
    croak "'$parent_pkg' do not have 'new'." unless $parent_pkg->can( 'new' );
    
    my $parent;
    my $simo;
    
    my $last_arg = pop;
    if( ref $last_arg eq 'ARRAY' ){
        my $parent_attrs = $last_arg;
        my @args = @_;
        
        @args = %{ @args } if ref $args[0] eq 'HASH';
        croak 'key-value pairs must be passed to new' if @args % 2;
        
        my %args = @args;
        my %parent_args;
        foreach my $parent_attr ( @{ $parent_attrs } ){
            $parent_args{ $parent_attr } = delete $args{ $parent_attr };
        }
        
        $parent = $parent_pkg->new( %parent_args );
        $simo = $self->Simo::new( %args );
    }
    elsif( ref $last_arg eq 'HASH' && @_ == 0  ){
        my $parent_args = $last_arg->{ parent_args };
        my $self_args = $last_arg->{ self_args };

        croak "'self_args' must be array reference." unless ref $self_args eq 'ARRAY';
        croak "'parent_args' must be array reference." unless ref $parent_args  eq 'ARRAY';
        
        $parent = $parent_pkg->new( @{ $parent_args } );
        $simo = $self->Simo::new( @{ $self_args } );
    }
    else{
        croak "'new_self_and_parent' argument is invalid.";
    }
    
    eval{ $parent = { %{ $parent }, %{ $simo } } };
    croak "'$parent_pkg' must be the class based on hash reference."
        if $@;
    return bless $parent, $class;
}

# required keys when object is created by new.
sub REQUIRED_ATTRS{ () }

# create accessor
sub ac(@){
    # Simo process
    my ( $self, $attr, @vals ) = _SIMO_process( @_ );
    
    # called by package
    return unless ref( $self );
    
    # call accessor
    $self->$attr( @vals );
}

# accessor option
my %VALID_AC_OPT = map{ $_ => 1 } qw(
                                      default constrain filter trigger
                                      hash_force read_only auto_build retval
                                      set_hook get_hook
                                     );

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
        croak "${pkg}::$attr '$key' is invalid accessor option" 
            unless $VALID_AC_OPT{ $key };
        
        carp "${pkg}::$attr : $@" 
            unless _SIMO_check_hook_options_order( $key, $hook_options_exist );
        
        $ac_opt->{ $key } = $val;
    }
    
    # regist ATTRS
    Simo->REGIST_ATTRS() if @Simo::ATTRIBUTES_CASHE;
    
    # create accessor
    {
        my $code = _SIMO_create_accessor( $pkg, $attr, $ac_opt );
        no warnings qw( redefine closure );
        eval"sub ${pkg}::${attr} $code";
        
        croak $@ if $@; # for debug. never ocuured.
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

my %VALID_SETTER_RETURN_VALUE = map { $_ => 1 } qw( undef old current self );

# create accessor.
sub _SIMO_create_accessor{
    my ( $pkg, $attr, $ac_opt ) = @_;
    
    my $e =
        qq/{\n/ .
        # arg recieve
        qq/    my \$self = shift;\n\n/;

    if( defined $ac_opt->{ default } ){
        # default value
        $e .=
        qq/    if( ! exists( \$self->{ $attr } ) ){\n/;

        if( ref $ac_opt->{ default } ){
        $e .=
        qq/        require Storable;\n/ .
        qq/        \$self->{ $attr } = Storable::dclone( \$ac_opt->{ default } );\n/;
        
        }
        else{
        $e .=
        qq/        \$self->{ $attr } = \$ac_opt->{ default };\n/;
        }
        
        $e .=
        qq/    }\n/ .
        qq/    \n/;
    }
    
    if( my $auto_build = $ac_opt->{ auto_build } ){
        unless( ref $auto_build eq 'CODE' ){
            # automatically call build method
            my $build_method = $attr;
            if( $attr =~ s/^(_*)// ){
                $build_method = $1 . "build_$attr";
            }
            
            Carp::croak( "'$build_method' must exist in '$pkg' when 'auto_build' option is set." )
                unless $pkg->can( $build_method );
            
            $ac_opt->{ auto_build } = \&{ "${pkg}::${build_method}" };
        }
        
        $e .=
        qq/    if( !\@_ && ! exists( \$self->{ $attr } ) ){\n/ .
        qq/        \$ac_opt->{ auto_build }->( \$self );\n/ .
        qq/    }\n/ .
        qq/    \n/;
    }
    

    if ( $ac_opt->{ read_only } ){
        $e .=
        qq/    if( \@_ ){\n/ .
        qq/        Simo::Error->throw(\n/ .
        qq/            type => 'read_only',\n/ .
        qq/            msg => "${pkg}::$attr is read only",\n/ .
        qq/            pkg => "$pkg",\n/ .
        qq/            attr => "$attr"\n/ .
        qq/        );\n/ .
        qq/    }\n\n/;
        
        goto END_OF_VALUE_SETTING;
    }
        
    $e .=
        qq/    if( \@_ ){\n/ .
    
    # rearrange value
        qq/        my \$val = \@_ == 1 ? \$_[0] :\n/;
    $e .= $ac_opt->{ hash_force } ?
        qq/                  \@_ >= 2 ? { \@_ } :\n/ :
        qq/                  \@_ >= 2 ? [ \@_ ] :\n/;
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
        qq/                Simo::Error->throw(\n/ .
        qq/                    type => 'type_invalid',\n/ .
        qq/                    msg => "${pkg}::$attr \$@",\n/ .
        qq/                    pkg => "$pkg",\n/ .
        qq/                    attr => "$attr",\n/ .
        qq/                    val => \$val\n/ .
        qq/                );\n/ .
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

    # setter return value;
    my $retval = $ac_opt->{ retval };
    $retval  ||= 'undef';
    Carp::croak( "${pkg}::$attr 'retval' option must be 'undef', 'old', 'current', or 'self'." )
        unless $VALID_SETTER_RETURN_VALUE{ $retval };
    
    if( $retval eq 'old' ){
    $e .=
        qq/        my \$old = \$self->{ $attr };\n\n/;
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
        qq/        }\n\n/;
    }
    
    
    #return
    if( $retval eq 'old' ){
        $e .= 
        qq/        return \$old;\n/;
    }
    elsif( $retval eq 'current' ){
        $e .= 
        qq/        return \$self->{ \$attr };\n/;
    }
    elsif( $retval eq 'self' ){
        # self
        $e .=
        qq/        return \$self;\n/;
    }
    else{
        $e .=
        qq/        return;\n/
    }
    
    $e .=
        qq/    }\n/;
    
    END_OF_VALUE_SETTING:
    
    if( defined $ac_opt->{ get_hook } ){
        # get_hook option
        # ( get_hook option is is now not recommended. this option will be deleted in future 2019/01/01 )
        $e .=
        qq/    my \$ret;\n/ .
        qq/    eval{ \$ret = \$ac_opt->{ get_hook }->( \$self, \$self->{ $attr } ) };\n/ .
        qq/    Carp::confess( \$@ ) if \$@;\n/;
        
        $e .=
        qq/    return \$ret;\n/ .
        qq/}\n/;
    }
    else{
        #return
        $e .=
        qq/    return \$self->{ $attr };\n/ .
        qq/}\n/;
    }
    return $e;
}

sub and_super{
    croak "Cannot pass args to 'and_super'" if @_;
    my ( $self, @args );
    my @caller;
    {
        package DB;
        @caller = caller 1;
        
        ( $self, @args ) = @DB::args;
    }
    
    my $sub = $caller[ 3 ];
    my ( $pkg, $sub_base ) = $sub =~ /^(.*)::(.+)$/;
    
    my @ret;
    {
        no strict 'refs';
        my $super = "SUPER::${sub_base}";
        @ret = eval "package $pkg; \$self->\$super( \@args );";
    }
    if( $@ ){ $@ =~ s/\s+at .+$//; croak $@ }
    return @ret;
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

# resist attribute specified by Attr
sub REGIST_ATTRS{
    my $self = shift;
    my @attributes_cashe = @Simo::ATTRIBUTES_CASHE;
    
    @Simo::ATTRIBUTES_CASHE = ();
    
    my %code_cache;
    my %pkg_registed;
    
    foreach ( @attributes_cashe ) {
        my ($pkg, $ref ) = @$_;
        unless ($code_cache{$pkg}) {

            $code_cache{$pkg} = {};
            
            no strict 'refs';
            foreach my $sym ( values %{"${pkg}::"} ) {

                next unless ref(*{$sym}{CODE}) eq 'CODE';

                $code_cache{$pkg}->{*{$sym}{CODE}} = *{$sym}{NAME};
            }
        }
        
        unless( $Simo::ATTRS{ $pkg } ){
            $Simo::ATTRS{ $pkg } = [];
        }
        
        my $accessor = $code_cache{ $pkg }->{ $ref };
        push @{ $Simo::ATTRS{ $pkg } }, $accessor;
        $pkg_registed{ $pkg }++;
    }
    
    my $e = '';
    foreach my $pkg ( keys %Simo::ATTRS ){
        unless( exists &{"${pkg}::ATTRS"} ){
            $e .=
            qq/package ${pkg};\n/ .
            qq/sub ATTRS{\n/ .
            qq/    my \$self = shift;\n/ .
            qq/    my \@super_attrs = eval{ \$self->SUPER::ATTRS };\n/ .
            qq/    \@super_attrs = () if \$@;\n/ .
            qq/    my \%attrs = map{ \$_ => 1 } \@{ \$Simo::ATTRS{ '${pkg}' } }, \@super_attrs;\n/ .
            qq/    return ( keys \%attrs );\n/ .
            qq/}\n/;
        }
    }
    eval $e;
    if( $@ ){ die "Cannot execute\n$@\n$e" }; # never occured.        

    return %pkg_registed;
}

# get attribute list
sub ATTRS{
    my $self = shift;
    if( @Simo::ATTRIBUTES_CASHE ){
        my %pkg_registed = Simo->REGIST_ATTRS();
        
        if( $pkg_registed{ ref $self || $self } ){
            return $self->ATTRS;
        }
        else{
            return ();
        }
    }
    else{
        return ();
    } 
}


###---------------------------------------------------------------------------
# The following methods is not recommended function 
# These method is not essential as nature of Simo object.
# These methods will be removed in future 2019/01/01
###---------------------------------------------------------------------------

# get value specify attr names
# ( not recommended )
sub get_attrs{
    carp "'get_attrs' is now not recommended. this method will be removed in future 2019/01/01";
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
# ( not recommended )
sub get_attrs_as_hash{
    carp "'get_attrs_as_hash' is now not recommended. this method will be removed in future 2019/01/01";
    my ( $self, @attrs ) = @_;
    my @vals = $self->get_attrs( @attrs );
    
    my %attrs;
    @attrs{ @attrs } = @vals;
    
    wantarray ? %attrs : \%attrs;
}

# set values
# ( not recommended )
sub set_attrs{
    carp "'set_attrs' is now not recommended. this method will be removed in future 2019/01/01";
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

=head1 NAME

Simo - Simple class builder [DISCOURAGED]

=head1 VERSION

Version 0.1201

=cut

=head1 CAUTION

This module is discouraged now, because I develope new module L<Object::Simple> now.

L<Object::Simple> is very simple class builder. It is clean, compact, and fast.

=cut

=head1 FEATURES

Simo is framework that simplify Object Oriented Perl.

The feature is that

=over 4

=item 1. You can define accessors in very simple way.

=item 2. new method is prepared.

=item 3. You can define default value of attribute.

=item 4. Error object is thrown, when error is occured.

=back

If you use Simo, you are free from bitter work 
writing new methods and accessors repeatedly.

=cut

=head1 SYNOPSIS

    #Class definition
    package Book;
    use Simo;
    
    sub title{ accessor }
    sub author{ accessor }
    sub price{ accessor }
    
    # Or ( ac is sintax sugar of accessor )
    package Book;
    use Simo;
    
    sub title{ ac }
    sub author{ ac }
    sub price{ ac }    
    
    
    # Using class
    use Book;
    my $book = Book->new( title => 'a', author => 'b', price => 1000 );
    
    # Default value of attribute
    sub author{ ac default => 'Kimoto' }
    
    #Automatically build of attribute
    sub author{ ac auto_build => 1 }
    sub build_author{ 
        my $self = shift;
        $self->author( $self->title . "b" );
    }
    
    sub title{ ac default => 'a' }
    
    # Constraint of attribute setting
    use Simo::Constrain qw( is_int isa );
    sub price{ ac constrain => sub{ is_int } }
    sub author{ ac constrain => sub{ isa 'Person' } }
    
    # Filter of attribute setting
    sub author{ ac filter => sub{ uc } }
    
    # Trigger of attribute setting
    
    sub date{ ac trigger => sub{ $_->year( substr( $_->date, 0, 4 ) ) } } 
    sub year{ ac }
    
    # Read only accessor
    sub year{ ac read_only => 1 }
    
    # Hash ref convert of attribute setting
    sub country_id{ ac hash_force => 1 }
    
    # Required attributes
    sub REQUIRED_ATTRS{ qw( title author ) }
    
    # Inheritance
    package Magazine;
    use Simo( base => 'Book' );
    
    # Mixin
    package Book;
    use Simo( mixin => 'Class::Cloneable' );
    
    # new method include
    package Book;
    use Simo( new => 'Some::New::Class' );

=cut

=head1 Manual

See L<Simo::Manual>. 

I explain detail of Simo.

If you are Japanese, See also L<Simo::Manual::Japanese>.

=cut

=head1 FUNCTIONS

=head2 accessor

is used to define accessor.

    package Book;
    use Simo;
    
    sub title{ accessor }
    sub author{ accessor }
    sub price{ accessor }

accessor is exported.

=head2 ac

ac is sintax sugar of accessor

    package Book;
    use Simo;
    
    sub title{ ac }
    sub author{ ac }
    sub price{ ac }

=cut

=head2 and_super

and_super is exported. This is used to call super method for REQUIRED_ATTRS.

    sub REQUIRED_ATTRS{ 'm1', 'm2', and_super }

=head1 METHODS

=head2 new

new method is prepared.

    use Book;
    my $book = Book->new( title => 'a', author => 'b', price => 1000 );

=head2 new_self_and_parent

new_self_and_parent resolve the inheritance of no Simo based class;

    $self->new_self_and_parent( @_, [ 'title', 'author' ] );
    
    $self->new_self_and_parent( { self_args => [], parent_args => [] } );

=head2 REQUIRED_ATTRS

this method is expected to override.

You can define required attribute.

    package Book;
    use Simo;
    
    sub title{ ac }
    sub author{ ac }
    sub price{ ac }
    
    sub REQUIRED_ATTRS{ qw( title author ) }

=cut

=head2 ATTRS

is attribute list. If you specify attribute 'Attr', This is automatically set.

    package Book;
    use Simo;
    
    sub title : Attr { ac }
    sub author : Attr { ac }

$self->ATTRS return ( 'title', 'author' )

=cut

=head2 REGIST_ATTRS

If you load module dinamically, Please call this medhos.

=cut

=head1 SEE ALSO

L<Simo::Constrain> - Constraint methods for Simo 'constrain' option.

L<Simo::Error> - Structured error system for Simo.

L<Simo::Util> - Utitlity class for Simo. 

L<Simo::Wrapper> - provide useful methods for object.

=head1 CAUTION

B<set_hook> and B<get_hook> option is now not recommended. These option will be removed in future 2019/01/01

B<non named defalut value definition> is now not recommended. This expression will be removed in future 2019/01/01

    sub title{ ac 'OO tutorial' } # not recommend. cannot be available in future.

B<get_attrs>,B<get_attrs_as_hash>,B<set_attrs>,B<run_methods> is now not recommended. These methods will be removed in future 2019/01/01

=cut

=head1 AUTHOR

Yuki Kimoto, C<< <kimoto.yuki at gmail.com> >>

=head1 SEE ALSO

L<Object::Simple>

L<Class::Accessor>,L<Class::Accessor::Fast>, L<Moose>, L<Mouse>.

=head1 COPYRIGHT & LICENSE

Copyright 2008 Yuki Kimoto, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.


=cut

1; # End of Simo
