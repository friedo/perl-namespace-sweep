package namespace::sweep;

# ABSTRACT: Sweep up imported subs in your classes

use strict;
use warnings;
use Data::Dump;

use Sub::Identify          0.04 'get_code_info';
use B::Hooks::EndOfScope   0.09 'on_scope_end';
use Package::Stash         0.33;

sub import { 
    my ( $class, %args ) = @_;

    my $cleanee = exists $args{-cleanee} ? $args{-cleanee} : scalar caller;

    on_scope_end { 
        no strict 'refs';
        my $st = $cleanee . '::';
        my $ps = Package::Stash->new( $cleanee );
        foreach my $sym( keys %{ $st } ) { 
            next unless exists &{ $st . $sym };
            my ( $pkg, $name ) = get_code_info \&{ $st . $sym };
            next if $pkg eq $cleanee;                       # defined in the cleanee pkg
            next if $pkg eq 'overload' and $name eq 'nil';  # magic overload method
            print "$sym --> $pkg :: $name\n";
            $ps->remove_symbol( '&' . $sym );
        } 

        printf "scope end %s\n", $cleanee;
    };

}

1;


