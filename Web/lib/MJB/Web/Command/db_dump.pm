package MJB::Web::Command::db_dump;
use Mojo::Base 'Mojolicious::Command';
use DBIx::Class::Schema::Config;

use Mojo::Util qw( getopt );

has description => 'Dump the mjb database.';
has usage       => "$0 dbc";

sub run {
    my ( $self, @args ) = @_;

    my $db_conf = DBIx::Class::Schema::Config->coerce_credentials_from_mojolike(
        DBIx::Class::Schema::Config->_make_connect_attrs(
            $self->app->config->{database}{mjb}
        )
    );

    if ( $db_conf->{dsn} =~ /^dbi:Pg:dbname=([^;]+);host=([^;]+)$/ ) {
        $db_conf->{dbname}   = $1;
        $db_conf->{hostname} = $2;
    }

    $ENV{PGPASSWORD} = $db_conf->{password};
    exec 'pg_dump', '-h', $db_conf->{hostname}, '-U', $db_conf->{user}, $db_conf->{dbname};

}

1;
