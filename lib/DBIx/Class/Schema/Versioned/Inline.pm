package DBIx::Class::Schema::Versioned::Inline;

=head1 NAME

DBIx::Class::Schema::Versioned::Inline - schema versioning for DBIx::Class with version information embedded inline in the schema definition

=head1 VERSION

Version 0.001

=cut

our $VERSION = '0.001';

=head1 SYNOPSIS

 package MyApp::Schema;

 use base 'DBIx::Class::Schema::Versioned::Inline';

 our $VERSION = '0.002';

 __PACKAGE__->load_namespaces;

 ...

 package MyApp::Schema::Result::Bar;

 use base 'DBIx::Class::Core';

 __PACKAGE__->table('bars');

 __PACKAGE__->add_columns(
    "bars_id",
    { data_type => 'integer', is_auto_increment => 1, },
    "age",
    { data_type => "integer", is_nullable => 1 },
    "height",
    {
      data_type   => "integer", is_nullable => 1,
      versioned   => { since => '0.003' }
    },
    "weight",
    {
      data_type   => "integer", is_nullable => 1,
      versioned   => { until => '0.3' }
    },
 );

 __PACKAGE__->set_primary_key('bars_id');

 __PACKAGE__->has_many(
    'foos', 'TestVersion::Schema::Result::Foo',
    'foos_id', { versioned => { until => '0.002' } },
 );

 __PACKAGE__->resultset_attributes( { versioned => { since => '0.002' } } );

 ...

 package MyApp::Schema::Result::Foo;

 use base 'DBIx::Class::Core';

 __PACKAGE__->table('foos');

 __PACKAGE__->add_columns(
    "foos_id",
    { data_type => 'integer', is_auto_increment => 1 },
    "age",
    {
      data_type => "integer", is_nullable => 1,
      versioned   => { since => '0.002' }
    },
    "height",
    {
     data_type => "integer", is_nullable => 1,
     versioned => { until => '0.001' }
    },
    "width",
    {
      data_type => "integer", is_nullable => 1,
      versioned => {
        since => [
          '0.002' => { renamed_from => 'height' },
          '0.3    => { is_nullable  => 0, default_value => 0 } },
        ],
      }
    },
    "bars_id",
    {
      data_type => 'integer', is_foreign_key => 1, is_nullable => 0,
      versioned => { since => '0.002' }
    },
 );

 __PACKAGE__->set_primary_key('foos_id');

 __PACKAGE__->belongs_to(
    'bar', 'TestVersion::Schema::Result::Bar',
    'bars_id', { versioned => { since => '0.002' } },
 );

 __PACKAGE__->resultset_attributes( { versioned => { until => '0.002' } } );

 ...

 package MyApp::Schema::Upgrade;

 use base 'DBIx::Class::Schema::Versioned::Inline::Upgrade';
 use DBIx::Class::Schema::Versioned::Inline::Upgrade qw/before after/;

 before '0.3.3' => sub {
     my $schema = shift;
     $schema->resultset('Foo')->update({ bar => '' });
 };

 after '0.3.3' => sub {
     my $schema = shift;
     # do something else
 };


=head1 DESCRIPTION

This module extends L<DBIx::Class::Schema::Versioned> using simple 'since' and 'until' markers within result classes to specify the schema version at which classes and columns were introduced or removed. Column since/until definitions are included as part of 'versioned' info in add_column(s).

=head2 since

When a class is added to a schema at a specific schema version version then a 'since' attribute must be added to the class which returns the version at which the class was added. For example:

 __PACKAGE__->resultset_attributes({ versioned => { since => '0.002' }});

It is not necessary to add this to the initial version of a class since any class without this atribute is assumed to have existed for ever.

Using 'since' in a column or relationship definition denotes the version at which the column/relation was added. For example:

 __PACKAGE__->add_column(
   "age",
   { data_type => "integer", is_nullable => 1,
     versioned => { since => '0.002' }
   }
 );

For changes to column_info such as a change of data_type then the value of C<since> should be an arrayref of C<< version => hashref >>. A simple C<since> without the hashref indicates the first version in which this column appeared:

 __PACKAGE__->add_column(
    "weight",
    { data_type => "integer", is_nullable => 1,
        versioned => {
            since => [

                # TODO - fixup this example

                {
                '0.002',                 # column first appeared at 0.002
                {
                    '0.4' => {               # change datatype at 0.4
                        data_type => "numeric",
                        size      => [10,2],
                    }
                },

                '0.401' => {             # add constraint+default at 0.401
                    is_nullable   => 0,
                    default_value => "0.0"
                }
            ]
        }
    }
 );

Note: if the Result containing the column includes a class-level C<since> then there is no need to add C<since> markers for columns created at the same version.

An example for a relationship:

 __PACKAGE__->belongs_to(
    'bar', 'MyApp::Schema::Result::Bar',
    'bars_id', { versioned => { since => '0.002' } },
 );

=head2 until

When used as a class attribute this should be the final schema version at which the class is to be used. The underlying database table will be removed when the schema is upgraded to a higher version. Example definition:

 __PACKAGE__->resultset_attributes({ versioned => { since => '0.3' }});

Using 'until' in a column or relationship definition will cause removal of the column/relation from the table when the schema is upgraded past this version.

=head2 renamed_from

For renaming a class:

 package MyApp::Schema::Result::Foo;

 __PACKAGE__->table('foos');
 __PACKAGE__->resultset_attributes({ versioned => { until => '0.4 }});

 package MyApp::Schema::Result::Fooey;

 __PACKAGE__->table('fooeys');
 __PACKAGE__->resultset_attributes({
     versioned => { since => '0.5, renamed_from => 'Foo' }
 });

When renaming a column we must use the extended form of C<since> as above where the value is an arrayref:

    # TODO - fixup this example

 __PACKAGE__->add_columns(
     "height",
     { data_type => "integer", versioned => { until => '0.001' } },
     "width",
     {
       data_type => "integer",
       versioned => { since => [ '0.002' => { renamed_from => 'height' } ] }
     },
 )

=head2 Upgrade.pm

For details on how to apply data modifications that might be required during an upgrade see L<DBIx::Class::Schema::Versioned::Inline::Upgrade>.

=cut

use warnings;
use strict;

use base 'DBIx::Class::Schema::Versioned';

use Carp;
use Data::Dumper::Concise;
use SQL::Translator;
use SQL::Translator::Diff;
use Try::Tiny;
use version 0.77;

our @schema_versions;

=head1 METHODS

Many methods are inherited or overloaded from L<DBIx::Class::Schema::Versioned>.

=head2 connection

Overloaded method. This checks the DBIC schema version against the DB version and ???? TODO ???? (undecided so far) if they are not the same or if the DB is unversioned.

=cut

sub connection {
    my $self = shift;
    $self->next::method(@_);

    my $conn_info = $self->storage->connect_info;
    $self->{vschema} = DBIx::Class::Version->connect(@$conn_info);
    my $conn_attrs = $self->{vschema}->storage->_dbic_connect_attributes || {};

    my $vtable = $self->{vschema}->resultset('Table');

    my $version = $conn_attrs->{_version} || $self->get_db_version();

    unless ($version) {

        # TODO: checks for unversioned
        # - do we throw exception?
        # - do we install automatically?
        # - can we be passed some method or connect arg?
        # for now just set $pversion to schema_version
        $version = $self->schema_version;
    }

    $self->versioned_schema( $version, $conn_attrs->{_type} );

    return $self;
}

=head2 deploy

Inherited method. Same as L<DBIx::Class::Schema/deploy> but also calls C<install>.

=head2 install

Inherited method. Call this to initialise a previously unversioned database.

=head2 ordered_schema_versions

Overloaded method. Returns an ordered list of schema versions. This is then used to produce a set of steps to upgrade through to achieve the required schema version.

=cut

sub ordered_schema_versions {
    my $self = shift;

    # add schema and database versions to list
    push @schema_versions, $self->get_db_version, $self->schema_version;

    # add Upgrade versions
    my $upgradeclass = ref($self) . "::Upgrade";
    eval {
        eval "require $upgradeclass" or return;
        push @schema_versions, $upgradeclass->versions;
    };

    return sort { version->parse($a) <=> version->parse($b) } do {
        my %seen;
        grep { !$seen{$_}++ } @schema_versions;
    };
}

=head2 upgrade

Inherited method. Call this to attempt to upgrade your database from the version it is at to the version this DBIC schema is at. If they are the same it does nothing.

=head2 upgrade_single_step

=over 4
 
=item Arguments: db_version - the version currently within the db
 
=item Arguments: target_version - the version to upgrade to

=back

Overloaded method. Call this to attempt to upgrade your database from the I<db_version> to the I<target_version>. If they are the same it does nothing.

All upgrade operations within this step are performed inside a single transaction so either all succeed or all fail. If successful the dbix_class_schema_versions table is updated with the I<target_version>.

This method may be called repeatedly by the L</upgrade> method to upgrade through a series of updates.

=cut

sub upgrade_single_step {
    my ( $self, $db_version, $target_version ) = @_;

    # db and schema at same version. do nothing
    if ( $db_version eq $target_version ) {
        carp 'Upgrade not necessary';
        return;
    }
    carp "attempting upgrade from $db_version to $target_version";

    my $sqlt_type = $self->storage->sqlt_type;

    # add Upgrade versions
    my $upgradeclass = ref($self) . "::Upgrade";
    eval {
        eval "require $upgradeclass" or return;
        my @sql = $upgradeclass->upgrade_to($target_version);
    };

    # translate current schema

    my $curr_tr = SQL::Translator->new(
        no_comments   => 1,
        parser        => 'SQL::Translator::Parser::DBIx::Class',
        parser_args   => { dbic_schema => $self, },
        producer      => $sqlt_type,
        show_warnings => 1,
    ) or $self->throw_exception( SQL::Translator->error );
    $curr_tr->translate;

    # translate target schema

    # our target future-versioned connect causes warning messages we don't want
    my $old_DBIC_NO_VERSION_CHECK = $ENV{DBIC_NO_VERSION_CHECK} || 0;
    $ENV{DBIC_NO_VERSION_CHECK} = 1;

    # we'll reuse connect_info from existing schema for target ver connect
    my $connect_info = $self->storage->connect_info;

    # padd out user/pass if they don't exist
    while ( scalar @$connect_info < 3 ) {
        push @$connect_info, undef;
    }

    # drop anything extra
    while ( scalar @$connect_info > 3 ) {
        pop @$connect_info;
    }

    # add next version
    push @$connect_info, { _version => $target_version };

    my $target_schema = ref($self)->connect(@$connect_info);

    # turn noises back to normal level
    $ENV{DBIC_NO_VERSION_CHECK} = $old_DBIC_NO_VERSION_CHECK;

    my $target_tr = SQL::Translator->new(
        no_comments   => 1,
        parser        => 'SQL::Translator::Parser::DBIx::Class',
        parser_args   => { dbic_schema => $target_schema, },
        producer      => $sqlt_type,
        show_warnings => 1,
    ) or $self->throw_exception( SQL::Translator->error );
    $target_tr->translate;

    # now we create the diff which we need as array so we can process one
    # line at a time

    my @diff = SQL::Translator::Diff->new(
        {
            output_db               => $sqlt_type,
            source_schema           => $curr_tr->schema,
            target_schema           => $target_tr->schema,
            ignore_index_names      => 1,
            ignore_constraint_names => 1,
        }
    )->compute_differences->produce_diff_sql;

    my $exception;

    try {
        $self->txn_do(
            sub {
                foreach my $line (@diff) {

                    # drop comments and BEGIN/COMMIT
                    next if $line =~ /(^--|BEGIN|COMMIT)/;
                    $self->storage->dbh_do(
                        sub {
                            my ( $storage, $dbh ) = @_;
                            $dbh->do($line);
                        }
                    );
                }
            }
        );
    }
    catch {
        $exception = $_;
    };

    if ($exception) {
        carp "ERROR: $exception\n";
    }
    else {

        # set row in dbix_class_schema_versions table
        $self->_set_db_version( { version => $target_version } );
    }
}

=head2 versioned_schema

=over 4

=item Arguments: version - the schema version we want to deploy

=back

Parse schema and remove classes, columns and relationships that are not valid for the requested version.

=cut

sub versioned_schema {
    my ( $self, $_version ) = @_;

    my $pversion = version->parse($_version);

    foreach my $source_name ( $self->sources ) {

        my $source = $self->source($source_name);

        # check columns before deciding on class-level since/until to make sure
        # we don't miss any versions

      COLUMN: foreach my $column ( $source->columns ) {

            my $column_info = $source->column_info($column);
            my $versioned   = $column_info->{versioned};

            my $since = $versioned->{since};
            my $until = $versioned->{until};

            # until is always a simple case so handle before since as
            # we may be able to ignore since completely

            if ($until) {

                # stash the discovered version number
                push @schema_versions, $until;

                if ( $pversion > version->parse($until) ) {
                    $source->remove_column($column);
                    next COLUMN;
                }
            }

            if ($since) {
                if ( ref($since) eq '' ) {

                    # a simple since => version

                    # stash the discovered version number
                    push @schema_versions, $since;

                    if ( $pversion < version->parse($since) ) {

                        # column not yet valid

                        $source->remove_column($column);
                        next COLUMN;
                    }
                }
                elsif ( ref($since) eq 'HASH' ) {

                    # since => { version => {}, ... }

                    # stash the discovered version numbers
                    push @schema_versions, keys %$since;

                    # now spin through our since entries
                    # in ascending order of version number

                  KEY: foreach my $key (
                        sort { version->parse($a) <=> version->parse($b) }
                        keys %$since
                      )
                    {

                        my $value = $since->{$key};

                        if ( ref($value) eq '' && $value eq '' ) {

                            # a simple "since" starting version

                            if ( $pversion < version->parse($key) ) {

                                # column not yet valid

                                $source->remove_column($column);
                                next COLUMN;
                            }
                        }
                        elsif ( ref($value) eq 'HASH' ) {

                            # we might have some column attributes to add/change

                            if ( $pversion < version->parse($key) ) {

                                # not valid yet

                                last KEY;
                            }

                            carp Dumper($value);
                            next COLUMN; #TEMP
                        }
                        else {
                            croak qq(Invalid "since" for column $column)
                              . qq( in $source_name);
                        }
                    }
                }
                else {
                    croak
                      qq(Invalid "since" for column $column in $source_name);
                }
            }
        }

        # check relations

        foreach my $relation_name ( $source->relationships ) {

            my $attrs = $source->relationship_info($relation_name)->{attrs};

            next unless defined $attrs;

            my $versioned = $attrs->{versioned};

            next unless defined $versioned;

            my $since = $versioned->{since};
            my $until = $versioned->{until};

            my $name = "$source_name relationship $relation_name";
            my $sub  = sub {
                my $source = shift;
                my %rels   = %{ $source->_relationships };
                delete $rels{$relation_name};
                $source->_relationships( \%rels );
            };
            $self->_since_until( $pversion, $since, $until, $name, $sub,
                $source );
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
        $self->_since_until( $pversion, $since, $until, $name, $sub, $self );
    }
}

sub _since_until {
    my ( $self, $pversion, $since, $until, $name, $sub, $thing ) = @_;

    push( @schema_versions, $since ) if $since;
    push( @schema_versions, $until ) if $until;

    if (   $since
        && $until
        && ( version->parse($since) > version->parse($until) ) )
    {
        $self->throw_exception("$name has since greater than until");
    }

    # until is absolute so parse before since
    if ( $until && $pversion > version->parse($until) ) {
        $sub->($thing);
    }
    if ( $since && $pversion < version->parse($since) ) {
        $sub->($thing);
    }
}

=head1 CAVEATS

Please anticipate API changes in this early state of development.

=head1 AUTHOR

Peter Mottram (SysPete), "peter@sysnix.com"

=head1 BUGS

LOTS of bugs and missing features right now.

NOTE: upgrades are NOT yet implemented.

Please report any bugs or feature requests via the project's GitHub issue tracker:

L<https://github.com/Sysnix/dbix-class-schema-versioned-jiftyesque/issues>

I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc DBIx::Class::Schema::Versioned::Inline

You can also look for information at:

=over 4

=item * GitHub repository

L<https://github.com/Sysnix/dbix-class-schema-versioned-inline>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/DBIx-Class-Schema-Versioned-Inline>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/DBIx-Class-Schema-Versioned-Inline>

=item * Search CPAN

L<http://search.cpan.org/dist/DBIx-Class-Schema-Versioned-Inline/>

=back

=head1 ACKNOWLEDGEMENTS

Thanks to Best Practical Solutions for the L<Jifty> framework and L<Jifty::DBI> which inspired this distribution. Thanks also to Matt S. Trout and all of the L<DBIx::Class> developers for an excellent distribution.

=head1 LICENSE AND COPYRIGHT

Copyright 2014 Peter Mottram (SysPete).

This program is free software; you can redistribute it and/or modify it under the terms of either: the GNU General Public License as published by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1;
