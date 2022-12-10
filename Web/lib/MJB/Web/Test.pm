package MJB::Web::Test;
use Import::Into;
use Test::More;
use Test::Deep;
use Test::Mojo::MJB;
use Test::Postgresql58;
use Mojo::File;

push our @ISA, qw( Exporter );
push our @EXPORT, qw( $run_code );

our $pgsql;

sub import {
    shift->export_to_level(1);
    my $target = caller;

    Mojo::Base     ->import::into($target, '-strict', '-signatures' );
    warnings       ->import::into($target);
    strict         ->import::into($target);
    Test::More     ->import::into($target);
    Test::Deep     ->import::into($target);
    Test::Mojo::MJB->import::into($target);
}

sub enable_testing_database {
    $pgsql = Test::Postgresql58->new()
        or BAILOUT( "PSQL Error: " . $Test::Postgresql58::errstr );

    load_psql_file("../DB/etc/schema.sql");

    $ENV{MJB_TESTMODE}         = 1;
    $ENV{MJB_DSN}              = $pgsql->dsn;
    $ENV{MJB_TESTMODE_TEMPDIR} = Mojo::File::tempdir->to_string;
}

sub load_psql_file {
    my ( $file ) = @_;

    open my $lf, "<", $file
        or die "Failed to open $file for reading: $!";
    my $content;
    while ( defined( my $line = <$lf> ) ) {
        next unless $line !~ /^\s*--/;
        $content .= $line;
    }
    close $lf;

    my $dbh = DBI->connect( $pgsql->dsn );
    for my $command ( split( /;/, $content ) ) {
        next if $command =~ /^\s*$/;
        $dbh->do( $command )
            or BAIL_OUT( "PSQL Error($file): $command: " . $dbh->errstr);
    }
    undef $dbh;
}

1;
