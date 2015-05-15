use strict;
use warnings;

use Test::More;
use Test::Exception;

use File::Spec;
use lib File::Spec->catdir( 't', 'lib' );
use aliased 'DBIx::Class::Schema::Versioned::Inline::VersionedSchema' => 'VS';

my ( $schema, $versioned_schema );

throws_ok( sub { VS->new }, qr/missing required arg/i, "new with no args" );

throws_ok(
    sub { VS->new( version => 1 ) },
    qr/missing required arg/i,
    "new without schema"
);

throws_ok(
    sub {
        VS->new(
            version => "xyz",
            schema  => "qw",
        );
    },
    qr/coercion.+failed/,
    "bad version"
);

lives_ok(
    sub {
        VS->new( schema => "TestVersion::Schema", );
    },
    "without version ok"
);
lives_ok(
    sub {
        VS->new(
            version => 0.001,
            schema  => "TestVersion::Schema",
        );
    },
    "version ok 0.001"
);
lives_ok(
    sub {
        VS->new(
            version => "v0.001",
            schema  => "TestVersion::Schema",
        );
    },
    "version ok v0.001"
);

lives_ok(
    sub {
        VS->new(
            version => "2.001.001",
            schema  => "TestVersion::Schema",
        );
    },
    "version ok 2.001.001"
);

throws_ok(
    sub {
        $versioned_schema = VS->new(
            version => 1,
            schema  => "NoSuch::_clas::ss",
        );
    },
    qr/INC/,
    "new schema => NoSuch::_clas::ss"
);

lives_ok(
    sub {
        $versioned_schema = VS->new(
            version => 0.001,
            schema  => "TestVersion::Schema",
        );
    },
    "good version and schema"
);

lives_ok( sub { $schema = $versioned_schema->schema }, "calling ->schema ok" );

isa_ok( $schema, "DBIx::Class::Schema" );

cmp_ok( $versioned_schema->version, 'eq', '0.001', "Version is 0.001" );

done_testing;
