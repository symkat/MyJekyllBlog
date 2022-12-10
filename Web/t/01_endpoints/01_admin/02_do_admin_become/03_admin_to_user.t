#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test confirms that an admin can login to a user account through the
# admin become functionality.
#
# 1. Create a user and record the id.
# 2. Log out of the user account.
# 3. Make a new user account, promote it to admin, and login.
# 4. Try to use admin_become and confirm that I am now logged in under the target user
# 5. Logout and confirm I am logged in under the admin account.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $user_id = $t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->stash->{person}->id;

# Logout
$t->get_ok( '/logout' )
    ->reset_session;

# Make a new user, promote to admin
my $admin_id = $t->create_user
    ->get_ok( '/profile' )
    ->code_block( sub {
        my $self = shift;

        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted user to an admin' );
    })->stash->{person}->id;

# Try to become the first user that was created, confirm we do.
$t->post_ok( '/admin', form => {
        uid => $user_id
    })
    ->header_is( location => '/dashboard' )
    ->status_is( 302 )
    ->get_ok( '/dashboard' )
    ->code_block(sub {
        is shift->stash->{person}->id, $user_id, 'Admin has become target user';
    });

# Logout and confirm the user id resets back to the admin one.
$t->get_ok( '/logout' )
    ->status_is( 302 )
    ->header_is( location => '/admin' )
    ->get_ok( '/admin' )
    ->code_block(sub {
        is shift->stash->{person}->id, $admin_id, 'Admin has become self again';
    });



done_testing;
