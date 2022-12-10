package MJB::Web::Command::create_user;
use Mojo::Base 'Mojolicious::Command';

use Mojo::Util qw( getopt );

has description => "Create an user account that can login to the panel.";
has usage       => "$0 create_user \"User Name\" email_address\@domain.com SecurePassword\n";

sub run {
    my ( $self, $name, $email, $password ) = @_;

    die "Error: you must provide an name.\n"
        unless $name;

    die "Error: you must provide an email address.\n"
        unless $email;

    die "Error: you must provide a valid email address.\n"
        unless $email =~ /@/;

    die "Error: you must provide a password.\n"
        unless $password;

    my $person = $self->app->db->storage->schema->txn_do( sub {
        my $person = $self->app->db->resultset('Person')->create({
            email     => $email,
            name      => $name,
        });
        $person->new_related('auth_password', {})->set_password($password);

        # Notify the system about the new account.
        $self->app->db->system_notes->create({
            source => 'User Registration (CLI)',
            content => "An account was created for $name",
        });

        return $person;
    });
}

1;
