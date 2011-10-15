package namespace::sweep;

# ABSTRACT: Sweep up imported subs in your classes

use strict;
use warnings;

use Scalar::Util 'blessed', 'reftype';
use Carp 'croak';

use Sub::Identify          0.04 'get_code_info';
use B::Hooks::EndOfScope   0.09 'on_scope_end';
use Package::Stash         0.33;

$namespace::sweep::AUTHORITY = 'cpan:FRIEDO';
$namespace::sweep::VERSION   = 0.1;

sub import { 
    my ( $class, %args ) = @_;

    my $cleanee = exists $args{-cleanee} ? $args{-cleanee} : scalar caller;
    my $also    = $args{-also};

    my $also_test = !$also                           ? sub { 0 }
                  : reftype $also eq reftype sub { } ? $also
                  : reftype $also eq reftype [ ]     ? sub { my %m = map { $_ => 1 } @$also; 
                                                             sub { $m{$_->[0]} } 
                                                           }->()
                  : reftype $also eq reftype qr//    ? sub { $_[0] =~ $also }
                  : defined $also                    ? sub { $_[0] eq $also }
                  : croak sprintf q{Don't know what to do with [%s] for -also}, $also;

    on_scope_end { 
        no strict 'refs';
        my $st = $cleanee . '::';
        my $ps = Package::Stash->new( $cleanee );

        my $sweep = sub { $ps->remove_symbol( '&' . $_[0] ) };

        my %keep;
        if ( $cleanee->can( 'meta' ) ) { 
            # look for moose roles 
            my $meta = $cleanee->meta;
            if ( blessed $meta && $meta->can( 'get_all_method_names' ) ) { 
                %keep = map { $_ => 1 } $meta->get_all_method_names;
            }
        }

        foreach my $sym( keys %{ $st } ) { 
            $sweep->( $sym ) and next if $also_test->( $sym );

            next unless exists &{ $st . $sym };
            next if $keep{$sym};

            my ( $pkg, $name ) = get_code_info \&{ $st . $sym };
            next if $pkg eq $cleanee;                       # defined in the cleanee pkg
            next if $pkg eq 'overload' and $name eq 'nil';  # magic overload method

            print "$sym --> $pkg :: $name\n";
            $sweep->( $sym );
        } 

        printf "scope end %s\n", $cleanee;
    };

}

1;


__END__

=pod

=encoding utf-8

=head1 NAME

namespace::sweep - Sweep up imported subs in your classes

=head1 SYNOPSIS

    package Foo;

    use namespace::sweep;
    use Some::Module qw(some_function);

    sub my_method { }

    package main;

    Foo->my_method;      # ok
    Foo->some_function;  # ERROR!

=head1 DESCRIPTION

Because Perl methods are just regular subroutines, it's difficult to tell what's a method
and what's just an imported function. As a result, imported functions can be called as
methods on your objects. This module will delete imported functions from your class's
symbol table, thereby ensuring 
