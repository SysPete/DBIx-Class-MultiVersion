package TestVersion::Schema::Result::Bar;
use base 'DBIx::Class::Core';
use strict;
use warnings;

__PACKAGE__->table('bars');

__PACKAGE__->add_columns(
    "bars_id",
    { data_type => 'integer', is_auto_increment => 1, },
    "age",
    { data_type => "integer", is_nullable => 1 },
    "height",
    { data_type => "integer", is_nullable => 1, extra => { since => '0.003' } },
    "weight",
    { data_type => "integer", is_nullable => 1, extra => { until => '0.3' } },
);

sub since { '0.002' }

1;
