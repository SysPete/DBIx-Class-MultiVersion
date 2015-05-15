package DBIx::Class::Schema::Versioned::Inline::VersionedSchema;

use Moo;

use Class::Load ':all';
use DBIx::Class::Schema::Versioned::Inline::Types -types;
use Types::PerlVersion qw/PerlVersion to_PerlVersion/;
use Types::Set qw/Set/;
use namespace::clean;

=head1 NAME

DBIx::Class::Schema::Versioned::Inline::VersionedSchema

=head1 DESCRIPTION

Applies versioning info for the requested schema class.

=head1 SYNOPSIS

  my $vs = DBIx::Class::Schema::Versioned::Inline::VersionedSchema->new(
      schema => "Interchange6::Schema",
      version => "0.004",
  );

=head1 ATTRIBUTES

=head2 schema

The schema class / loaded schema. Given a class name will attempt to coerce
into a fully inflated class.

=cut

has schema => (
    is       => 'ro',
    isa      => DbicSchema,
    required => 1,
    coerce   => 1,
);

=head2 schema_versions

The set of available schema versions.

=cut

has schema_versions => (
    is      => 'ro',
    isa     => Set [PerlVersion],
    coerce  => 1,
    default => sub { +[] },
    handles => {
        add_version   => 'insert',
        version_count => 'size',
        version_list  => 'members',
    },
    init_arg => undef,
);

=head2 version

The schema version required. If not supplied then $VERSION of L</schema_class>
will be used.

=cut

has version => (
    is     => 'ro',
    isa    => PerlVersion,
    coerce => 1,
    writer => 'set_version',
);

=head1 METHODS

=head2 BUILD

Called automatically immediately after object creation this method sets the
following attributes: 

=cut

sub BUILD {
    my $self = shift;

    my $schema = $self->schema;

    # add $VERSION from schema class to schema_versions and also set
    # our version to this if it is not defined
    {
        no strict 'refs';
        my $schema_class = ref($schema);
        my $schema_version = ${ "${schema_class}::VERSION" };
        die "Schema class $schema_class has no \$VERSION defined."
          unless defined $schema_version;

        $self->add_version($schema_version);
        $self->set_version($schema_version) unless defined $self->version;
    }

    # now spin through schema collecting versions and stripping out

    foreach my $source_name ( $schema->sources ) {

        my $source = $schema->source($source_name);

        # check columns before deciding on class-level since/until to make sure
        # we don't miss any versions

        foreach my $column ( $source->columns ) {

            my $column_info = $source->column_info($column);
            my $versioned   = $column_info->{versioned};

            my ( $changes, $renamed, $since, $until );

            if ($versioned) {
                $changes = $versioned->{changes};
                $renamed = $versioned->{renamed_from};
                $since   = $versioned->{since};
                $until   = $versioned->{until};
                $until   = $versioned->{till} if defined $versioned->{till};
            }
            else {
                $changes = $column_info->{changes};
                $renamed = $column_info->{renamed_from};
                $since   = $column_info->{since};
                $until   = $column_info->{until};
                $until   = $column_info->{till} if defined $column_info->{till};
            }

            # handle since/until first

            my $name = "$source_name column $column";
            my $sub  = sub {
                my $source = shift;
                $source->remove_column($column);
            };
            $self->since_until( $since, $until, $name, $sub, $source );

            # handled renamed column

            if ($renamed) {
                unless ($since) {

                    # catch sitation where class has since but renamed_from
                    # on column does not (renamed PK columns for example)

                    my $rsa_ver = $source->resultset_attributes->{versioned};
                    $since = $rsa_ver->{since} if $rsa_ver->{since};
                }
            }

            # handle changes

            if ($changes) {
                $schema->throw_exception("changes not a hashref in $name")
                  unless ref($changes) eq 'HASH';

                foreach my $change_version ( sort version_sort keys %$changes )
                {

                    my $change_value = $changes->{$change_version};

                    $schema->throw_exception(
                        "not a hasref in $name changes $change_version")
                      unless ref($change_value) eq 'HASH';

                    # stash the version
                    $self->add_version($change_version);

                    if ( $self->version >= to_PerlVersion($change_version) ) {
                        unless ( $source->remove_column($column)
                            && $source->add_column( $column => $change_value ) )
                        {
                            $schema->throw_exception(
                                "Failed change $change_version for $name");
                        }
                    }
                }
            }
        }

        # check relations

        foreach my $relation_name ( $source->relationships ) {

            my $attrs = $source->relationship_info($relation_name)->{attrs};

            next unless defined $attrs;

            my $versioned = $attrs->{versioned};

            # TODO: changes/renamed_from for relations?
            my ( $since, $until );
            if ($versioned) {
                $since = $versioned->{since};
                $until = $versioned->{until};
                $until = $versioned->{till} if defined $versioned->{till};
            }
            else {
                $since = $attrs->{since};
                $until = $attrs->{until};
                $until = $attrs->{till} if defined $attrs->{till};
            }

            my $name = "$source_name relationship $relation_name";
            my $sub  = sub {
                my $source = shift;
                my %rels   = %{ $source->_relationships };
                delete $rels{$relation_name};
                $source->_relationships( \%rels );
            };
            $self->since_until( $since, $until, $name, $sub, $source );
        }

        # check class-level since/until

        my ( $since, $until );

        my $versioned = $source->resultset_attributes->{versioned};

        if ( defined $versioned ) {
            $since = $versioned->{since} if defined $versioned->{since};
            $until = $versioned->{until} if defined $versioned->{until};
        }

        my $name = $source_name;
        my $sub  = sub {
            my $class = shift;
            $class->unregister_source($source_name);
        };
        $self->since_until( $since, $until, $name, $sub, $schema );
    }
}

=head2 add_version( $version )

Add $version to L</schema_versions>.

=head2 ordered_schema_versions

Returns L</schema_versions> as an ordered list.

=cut

sub ordered_schema_versions {
    return map { $_->stringify } sort shift->version_list;
}

=head2 set_schema( $version )

Writer for L</schema>.

=head2 set_version( $version )

Writer for L</version>.

=head2 since_until( $since, $until, $name, $sub, $thing )

If $since and/or $until are defined and are valid for the required version
then call $sub with $thing as argument.

=cut

sub since_until {
    my ( $self, $since, $until, $name, $sub, $thing ) = @_;

    my ( $pv_since, $pv_until );

    if ($since) {
        $pv_since = to_PerlVersion($since);
        $self->add_version($since);
    }
    if ($until) {
        $pv_until = to_PerlVersion($until);
        $self->add_version($until);
    }

    if ( $since && $until && $pv_since > $pv_until ) {
        $self->throw_exception("$name has since greater than until");
    }

    # until is absolute so parse before since
    if ( $until && $self->version >= $pv_until ) {
        $sub->($thing);
    }
    if ( $since && $self->version < $pv_since ) {
        $sub->($thing);
    }
}

=head2 version_count

Returns the number of versions held in L</schema_versions>.

=head2 version_list

Returns L</schema_versions> as an array.

=head2 version_sort

Sort block to allow sorting of version strings as PerlVersion objects.

  sort version_sort @list_of_version_strings;

=cut

sub version_sort {
    to_PerlVersion($a) <=> to_PerlVersion($b);
}

1;
