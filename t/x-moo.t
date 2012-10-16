use Test::More;

BEGIN {
	eval 'require Moo; 1'
		or plan skip_all => 'This test requires Moo'
}

BEGIN {
	package Local::Noisy;
	use Moo::Role;
	requires 'noise';
	sub loud_noise { uc(shift->noise) };
};

BEGIN {
	package Local::Cow;
	use Moo;
	use namespace::sweep;
	sub noise { 'moo' };
	with qw( Local::Noisy );
};

ok not $INC{'Moose.pm'};

can_ok 'Local::Cow' => qw( new );
can_ok 'Local::Cow' => qw( noise );
can_ok 'Local::Cow' => qw( loud_noise );

is(
	'Local::Cow'->new->loud_noise,
	'MOO',
);

done_testing;
