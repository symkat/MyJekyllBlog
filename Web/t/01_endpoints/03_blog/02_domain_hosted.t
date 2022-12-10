#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# Ensure that the route for creating a blog on a hosted domain behaves
# as expected.  Anonymouse users should be dismissed to the login page.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Ensure that a user who hasn't logged in cannot access this page.
$t->get_ok( '/blog/domain/hosted' )
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

# Confirm that the page exists and is served.
$t->get_ok( '/blog/domain/hosted' )
    ->status_is( 200 );

done_testing();
