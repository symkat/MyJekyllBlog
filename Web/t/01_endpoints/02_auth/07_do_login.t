#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that login works.
#
# It will create an account through the normal registration, logout,
# confirm it is logged out, log in, and confirm it is logged in.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that open registration method is enabled.
$t->app->config->{register}{enable_open} = 1;

# Try creating a valid account, ensure it exists in the DB.
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

# Remove session information so we are logged out of the fred account.
$t->reset_session;

# Confirm the reset session logged us out by testing if the /dashboard redirects to login.
$t->get_ok( '/dashboard' )
    ->status_is( 302 )
    ->header_is( location => '/login' );

# Try to login to the newly created account.
$t->post_ok( '/login', form => { 
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
    })->status_is( 302 
    )->header_is( location => '/dashboard', 'Login redirected to dashboard' )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })->get_ok( '/'
    )->code_block( sub {
        is(shift->stash->{person}->name, 'fred', 'Got the fred after login...');
    });

done_testing();
