#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a regular user cannot use the admin become functionality.
#
# 1. Create a user and record the id.
# 2. Log out of the user account.
# 3. Make a new user account and login.
# 4. Try to use admin_become and confirm rejection
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $user_id = $t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->stash->{person}->id;

# Logout
$t->get_ok( '/logout' )
    ->reset_session;

# Make a new user, try to become the first user and confirm we do not.
$t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->post_ok( '/admin', form => {
        uid => $user_id
    })
    ->header_is( location => '/dashboard' )
    ->status_is( 302 )
    ->get_ok( '/dashboard' )
    ->code_block(sub {
        isnt shift->stash->{person}->id, $user_id, 'Did not become user.';
    });

done_testing;
