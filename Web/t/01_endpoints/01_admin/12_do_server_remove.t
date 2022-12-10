#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that servers can be removed through the admin panel.
#
# It creates an admin user, who then creates a servers name, and it confirms the
# server exists in the stash for the /admin/servers page, then it deletes the
# server and confirms it is no longer available.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure an unauthed user cannot access this.
$t->get_ok( '/admin/servers' )
    ->status_is( 302 )
    ->header_is( location => '/login', 'Anonymouse users may not access the admin server panel.' );

# Register a user account and log into it.  
#
# A normal user should still not be allowed to view this page.
#
# Promote the user to an admin
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })
    ->get_ok( '/admin/servers' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Normal users may not access the admin server panel.' )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Add a server.
$t->post_ok( '/admin/server', form => { 
        server_fqdn   => 'example-deploy-server.com',
    })
    ->header_is( location => '/admin/servers' );

# Check to ensure that the server exists now, and remove it.
$t->get_ok( '/admin/servers' )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{servers}), 'ARRAY', 'Have an array ref for servers';
        is $self->stash->{servers}->[0]->hostname, 'example-deploy-server.com', 'Have an entry for the server.';

        # Now we will remove the server.
        $t->post_ok( '/admin/server/remove', form => { sid => $self->stash->{servers}->[0]->id })
            ->header_is( location => '/admin/servers' );
    });

# Confirm the server has been removed.
$t->get_ok( '/admin/servers' )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{servers}), 'ARRAY', 'Have an array ref for servers';
        is scalar(@{$self->stash->{servers}}), 0, 'Server was removed.';
    });

done_testing;
