use 5.006;
use strict;
use warnings;
use ExtUtils::MakeMaker;

my $MIN_DBIC_VERSION = '0.082820';

my %EUMM_ARGS = (
    NAME               => 'DBIx::Class::MultiVersion',
    AUTHOR             => q{Peter Mottram (SysPete) <peter@sysnix.com>},
    VERSION_FROM       => 'lib/DBIx/Class/MultiVersion.pm',
    ABSTRACT_FROM      => 'lib/DBIx/Class/MultiVersion.pm',
    LICENSE            => 'perl',
    PL_FILES           => {},
    MIN_PERL_VERSION   => 5.006,
    CONFIGURE_REQUIRES => {
        'ExtUtils::MakeMaker' => 0,
        'DBIx::Class'         => $MIN_DBIC_VERSION,
    },
    BUILD_REQUIRES => {
        'Class::Load'                 => 0,
        'DBIx::Class::Schema::Loader' => '0.07040',
        'File::Spec'                  => '3.47',
        'Test::Deep'                  => 0,
        'Test::Exception'             => 0,
        'Test::More'                  => 0,
    },
    PREREQ_PM => {
        'DBIx::Class'        => $MIN_DBIC_VERSION,
        'Moo'                => '2.000',
        'Try::Tiny'          => '0.18',
        'Type::Tiny'         => '1.000005',
        'Types::PerlVersion' => '0.002',
        'Types::Set'         => '0.003',
    },
    dist       => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean      => { FILES    => 'DBIx-Class-MultiVersion-*' },
    META_MERGE => {
        resources => {
            repository =>
              'https://github.com/SysPete/DBIx-Class-MultiVersion.git',
            bugtracker =>
              'https://github.com/SysPete/DBIx-Class-MultiVersion/issues',
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

