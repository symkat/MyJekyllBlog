#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the forgot password controller works correctly.
#
# It will create an account, log out of that account, and request a password
# reset.  It will confirm a token exists in the DB, then reset the password,
# and finally log into the account with the new password.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that open registration method is enabled and create a user account.
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->get_ok( '/logout' )
    ->status_is( 302 )
    ->header_is( location => '/' );

# Fill out the form and fetch the reset token.
my $token = $t->post_ok( '/forgot', form => {
        email => 'fred@blog.com',
    })
    ->status_is( 302 )
    ->header_is( location => '/forgot' )
    ->stash->{token};

# Confirm the token exists in the DB.
is $t->app->db->auth_tokens( { token => $token } )->count, 1, "The token exists.";

# Reset the password.
$t->post_ok( "/reset/$token", form => {
        password         => 'NewPassword',
        password_confirm => 'NewPassword',
    })
    ->status_is( 302 )
    ->header_is( location => '/dashboard' );

# Remove session information so we are logged out of the fred account.
$t->reset_session;

# Confirm the reset session logged us out by testing if the /dashboard redirects to login.
$t->get_ok( '/dashboard' )
    ->status_is( 302 )
    ->header_is( location => '/login' );

# Try to login to the new password.
$t->post_ok( '/login', form => { 
        email            => 'fred@blog.com',
        password         => 'NewPassword',
    })->status_is( 302 
    )->header_is( location => '/dashboard', 'Login redirected to dashboard' )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })->get_ok( '/'
    )->code_block( sub {
        is(shift->stash->{person}->name, 'fred', 'Got the fred after login...');
    });

done_testing();
