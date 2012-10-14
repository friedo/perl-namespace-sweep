use Test::More tests => 1;

{
	package Local::Cow;
	use Moo;
	use namespace::sweep;
}

ok not $INC{'Moose.pm'};
