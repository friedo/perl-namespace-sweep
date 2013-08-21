package namespace::sweep;

# ABSTRACT: Sweep up imported subs in your classes

use strict;
use warnings;

use Scalar::Util 'blessed', 'reftype';
use List::Util 'first';
use Carp 'croak';
use Data::Dumper;

use Sub::Identify          0.04 'get_code_info';
use B::Hooks::EndOfScope   0.09 'on_scope_end';
use Package::Stash         0.33;

$namespace::sweep::AUTHORITY = 'cpan:FRIEDO';

sub import { 
    my ( $class, %args ) = @_;

    my $cleanee = exists $args{-cleanee} ? $args{-cleanee} : scalar caller;
    my %run_test = (
        -also   => sub { +return },
        -except => sub { +return },
    );

    foreach my $t (keys %run_test)
    {
        next unless exists $args{$t};
        
        unless ( ref $args{$t} and reftype($args{$t}) eq reftype([]) )
        {
            $args{$t} = [ $args{$t} ];
        }
        
        my @tests;
        foreach my $arg (@{ $args{$t} }) { 
            my $test = !$arg                           ? sub { 0 }
                     : !ref( $arg )                    ? sub { $_[0] eq $arg }
                     : reftype $arg eq reftype sub { } ? sub { local $_ = $_[0]; $arg->() }
                     : reftype $arg eq reftype qr//    ? sub { $_[0] =~ $arg }
                     : croak sprintf q{Don't know what to do with [%s] for %s}, $arg, $t;

            push @tests, $test;
        }
        
        $run_test{$t} = sub { 
            return 1 if first { $_->( $_[0] ) } @tests;
            return;
        };
    }

    on_scope_end { 
        no strict 'refs';
        my $st = $cleanee . '::';
        my $ps = Package::Stash->new( $cleanee );

        my $sweep = sub { 
            # stolen from namespace::clean
            my @symbols = map {
                my $name = $_ . $_[0];
                my $def = $ps->get_symbol( $name );
                defined($def) ? [$name, $def] : ()
            } '$', '@', '%', '';

            $ps->remove_glob( $_[0] );
            $ps->add_symbol( @$_ ) for @symbols;
        };

        my %keep;
        my $class_of_cm = UNIVERSAL::can('Class::MOP', 'can')  && 'Class::MOP'->can('class_of');
        my $class_of_mu = UNIVERSAL::can('Mouse::Util', 'can') && 'Mouse::Util'->can('class_of');
        if ( $class_of_cm or $class_of_mu ) { 
            # look for moose-ish composed methods
            my ($meta) =
                grep { !!$_ }
                map  { $cleanee->$_ }
                grep { defined $_ }
                ($class_of_cm, $class_of_mu);
            if ( blessed $meta && $meta->can( 'get_all_method_names' ) ) { 
                %keep = map { $_ => 1 } $meta->get_all_method_names;
            }
        }

        foreach my $sym( keys %{ $st } ) { 
            next if $run_test{-except}->( $sym );
            $sweep->( $sym ) and next if $run_test{-also}->( $sym );

            next unless exists &{ $st . $sym };
            next if $keep{$sym};

            my ( $pkg, $name ) = get_code_info \&{ $st . $sym };
            next if $pkg eq $cleanee;                       # defined in the cleanee pkg
            next if $pkg eq 'overload' and $name eq 'nil';  # magic overload method

            $sweep->( $sym );
        } 
    };

}

1;


__END__

=pod

=encoding utf-8

=head1 SYNOPSIS

 package Foo;
 
 use namespace::sweep;
 use Some::Module qw(some_function);
 
 sub my_method { 
      my $foo = some_function();
      ...
 }
 
 package main;
 
 Foo->my_method;      # ok
 Foo->some_function;  # ERROR!

=head1 DESCRIPTION

Because Perl methods are just regular subroutines, it's difficult to tell what's a method
and what's just an imported function. As a result, imported functions can be called as
methods on your objects. This pragma will delete imported functions from your class's
symbol table, thereby ensuring that your interface is as you specified it. However,
code inside your module will still be able to use the imported functions without any 
problems.

=head1 ARGUMENTS

The following arguments may be passed on the C<use> line:

=over

=item -cleanee

If you want to clean a different class than the one importing this pragma, you can 
specify it with this flag. Otherwise, the importing class is assumed.

 package Foo;
 use namespace::sweep -cleanee => 'Bar'   # sweep up Bar.pm

=item -also

This lets you provide a mechanism to specify other subs to sweep up that would not
normally be caught. (For example, private helper subs in your module's class that
should not be called as methods.)

 package Foo;
 use namespace::sweep -also => '_helper';         # sweep single sub
 use namespace::sweep -also => [qw/foo bar baz/]; # list of subs
 use namespace::sweep -also => qr/^secret_/;      # matching regex

You can also specify a subroutine reference which will receive the symbol name as
C<$_>. If the sub returns true, the symbol will be swept.

 # sweep up those rude four-letter subs
 use namespace::sweep -also => sub { return 1 if length $_ == 4 }

You can also combine these methods into an array reference:

 use namespace::sweep -also => [
     'string',
     sub { 1 if /$pat/ and $_ !~ /$other/ },
     qr/^foo_.+/,
 ];

=item -except

This lets you specify subroutines which should be kept despite eveything else.
For example, if you use L<Exporter> or L<Sub::Exporter>, you probably want to
keep the C<import> method installed into your package:

 package Foo;
 use Exporter 'import';
 use namespace::sweep -except => 'import';

If using sub attributes, then you may need to keep certain special subs:

 use namespace::sweep -except => qr{^(FETCH|MODIFY)_\w+_ATTRIBUTES$};

When a sub matches both C<< -also >> and C<< -except >>, then C<< -except >> "wins".

=back

=head1 RATIONALE 

This pragma was written to address some problems with the excellent L<namespace::autoclean>.
In particular, namespace::autoclean will remove special symbols that are installed by 
L<overload>, so you can't use namespace::autoclean on objects that overload Perl operators.

Additionally, namespace::autoclean relies on L<Class::MOP> to figure out the list of methods
provided by your class. This pragma does not depend on Class::MOP or L<Moose>, so you can
use it for non-Moose classes without worrying about heavy dependencies. 

However, if your class has a Moose (or Moose-compatible) C<meta> object, then that will be
used to find e.g. methods from composed roles that should not be deleted.

In most cases, namespace::sweep should work as a drop-in replacement for namespace::autoclean.
Upon release, this pragma passes all of namespace::autoclean's tests, in addition to its own.

=head1 CAVEATS

This is an early release and there are bound to be a few hiccups along the way.

=head1 ACKNOWLEDGEMENTS 

Thanks Florian Ragwitz and Tomas Doran for writing and maintaining namespace::autoclean. 

Thanks to Toby Inkster for submitting some better code for finding C<meta> objects.

=head1 SEE ALSO

L<namespace::autoclean>, L<namespace::clean>, L<overload>


=cut

