package # hide from PAUSE
  DBIx::Class::Schema::Versioned::Inline::Types;

use strict;
use warnings;

use Type::Utils qw(:all);
use Type::Library -base, -declare => qw( DbicSchema );
use Class::Load qw( load_class );

extends "Types::Standard";

class_type DbicSchema, { class => "DBIx::Class::Schema" };

coerce DbicSchema, from Str => via { load_class( $_ ) && $_->clone };

1;
=head1 NAME

DBIx::Class::Schema::Versioned::Inline::Types

=head1 DESCRIPTION

Extends L<Types::Standard> with the following types:

=over

=item * DbicSchema

=back
