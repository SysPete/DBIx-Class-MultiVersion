use 5.006;
use strict;
use warnings FATAL => 'all';
use ExtUtils::MakeMaker;

my $DBIC_VERSION = '0.082820';

my %EUMM_ARGS = (
    NAME         => 'DBIx::Class::Schema::Versioned::Inline',
    AUTHOR       => q{Peter Mottram (SysPete) <peter@sysnix.com>},
    VERSION_FROM => 'lib/DBIx/Class/Schema/Versioned/Inline.pm',
    ABSTRACT =>
'Schema versioning for DBIx::Class with version information embedded inline in the schema definition.',
    LICENSE            => 'perl',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'DBIx::Class'         => $DBIC_VERSION,
    },
    BUILD_REQUIRES => {
        'Class::Load'                 => 0,
        'DBIx::Class::Schema::Loader' => '0.07040',
        'File::Spec'                  => '3.47',
        'Test::Deep'                  => 0,
        'Test::Exception'             => 0,
        'Test::Roo'                   => '1.003',
        'Test::Warnings'              => '0.012',
    },
    PREREQ_PM => {
        'DBIx::Class'        => $DBIC_VERSION,
        'Moo'                => '2.000',
        'Try::Tiny'          => '0.18',
        'Type::Tiny'         => '1.000005',
        'Types::PerlVersion' => '0.002',
    },
    dist => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean      => { FILES => 'DBIx-Class-Schema-Versioned-Inline-*' },
    META_MERGE => {
        resources => {
            repository =>
'https://github.com/Sysnix/dbix-class-schema-versioned-inline.git',
            bugtracker =>
'https://github.com/Sysnix/dbix-class-schema-versioned-inline/issues',
            IRC => 'irc://irc.perl.org/#dbix-class',
        },
    },
);

my %DBIC_PREREQ_PM = %{
    eval {
        require DBIx::Class::Optional::Dependencies;
        DBIx::Class::Optional::Dependencies->req_list_for( [qw( deploy )] );
    }
      || {}
};
$EUMM_ARGS{PREREQ_PM} =
  { %DBIC_PREREQ_PM, %{ $EUMM_ARGS{PREREQ_PM} || {} }, };

my %DBIC_BUILD_REQUIRES = %{
    eval {
        require DBIx::Class::Optional::Dependencies;
        DBIx::Class::Optional::Dependencies->req_list_for(
            [qw( rdbms_sqlite )] );
    }
      || {}
};
$EUMM_ARGS{BUILD_REQUIRES} =
  { %DBIC_BUILD_REQUIRES, %{ $EUMM_ARGS{BUILD_REQUIRES} || {} }, };

ExtUtils::MakeMaker::WriteMakefile(%EUMM_ARGS);
