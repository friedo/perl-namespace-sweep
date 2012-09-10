{ 
    package Foo; 
    use namespace::sweep -except => [ 'import' ]; 
    use Exporter 'import';
    @EXPORT_OK = ( '$foo' );
    our $foo = 1; 
    BEGIN { $INC{'Foo.pm'} = 1 } 
} 

package Bar; 

use Test::More tests => 1;
use Foo;

is $foo, 1;

