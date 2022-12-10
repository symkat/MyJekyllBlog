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
# reset.  It will confirm a token exists in the DB.
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

done_testing();
