use Test::More tests => 3;

BEGIN {
    package Local::Clean;
    use Scalar::Util qw( blessed reftype );
    use namespace::sweep;
};

BEGIN {
    package Local::Dirty;
    use Scalar::Util qw( blessed reftype );
    use namespace::sweep -except => 'blessed';
};

BEGIN {
    package Local::Filthy;
    use Scalar::Util qw( blessed reftype );
    use namespace::sweep -except => [ qr{e} ];
};

ok(
    !Local::Clean->can('blessed') && !Local::Clean->can('reftype'),
    'default'
);

ok(
    Local::Dirty->can('blessed') && !Local::Dirty->can('reftype'),
    '-except "subname"'
);

ok(
    Local::Filthy->can('blessed') && Local::Filthy->can('reftype'),
    '-except qr{regex}'
);
