#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that an anonymouse user may not use the
# admin become functionality.
#
# 1. Create a user and record the id.
# 2. Log out of the user account.
# 3. As an anonymouse user try to use admin_become and confirm rejection
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $user_id = $t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->stash->{person}->id;

# Logout
$t->get_ok( '/logout' )
    ->reset_session;

$t->post_ok( '/admin', form => {
        uid => $user_id
    })
    ->header_is( location => '/login' )
    ->status_is( 302 )
    ->code_block(sub {
        is shift->stash->{person}, undef, 'No person object loaded';
    });

done_testing;
