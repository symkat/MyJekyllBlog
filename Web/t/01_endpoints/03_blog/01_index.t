#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# Test to ensure that the blog index page redirects to the page for
# creating the blog on a hosted page.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Ensure that a user who hasn't logged in cannot access this page.
$t->get_ok( '/blog' )
    ->status_is( 302 )
    ->header_is( location => '/login' );

# Make sure that open registration method is enabled and create a user account.
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->get_ok( '/' );

# Confirm the blog index page exists.
$t->get_ok( '/blog' )
    ->status_is( 200 );

done_testing();
