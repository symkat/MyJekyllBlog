#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that logout works.
#
# It will create an account and then confirm that it can logout of that
# account without resetting the session.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that open registration method is enabled and create a user account.
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })->status_is( 302 
    )->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })->code_block( sub {
        is( shift->app->db->resultset('Person')->search( { name => 'fred'})->count, 1, 'User created.');
    })->get_ok( '/'
    )->code_block( sub {
        is(shift->stash->{person}->name, 'fred', 'Got the fred after login...');
    });

# Use the logout form the logout.
$t->get_ok( '/logout' )
    ->status_is( 302 )
    ->header_is( location => '/' );

# Confirm the logout form logged us out by testing if the /dashboard redirects to login.
$t->get_ok( '/dashboard' )
    ->status_is( 302 )
    ->header_is( location => '/login' );

done_testing();
