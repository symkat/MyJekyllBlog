#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the settings setup page exists after a blog
# is created and can be accessed.
#
# It also ensures that a user cannot access a settings page that doesn't
# belong to them.
#
# A user account will be registered, and the user will create a blog on 
# blog.example.com, and then it will be confirmed that a blog exists.
#
# With this blog existing, the settings page should give a 200.  Before existing,
# it should redirect to the dashboard.  If a user accesses a blog that they did
# not create, it should also redirect to the dashboard.
#
# Note: During testing ->jekyll uses an alternative root path to store repos at.
#       When using ->jekyll in tests, you MUST call $t->clear_tempdir when you are
#       done testing to remove the altrernative jekyll root.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

$t->get_ok( '/blog/1/settings' )
    ->status_is( 302 )
    ->header_is( location => '/login', "Cannot access settings without account.");

# Make sure that open registration method is enabled and create a user account.
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 );

$t->get_ok( '/blog/1/settings' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', "Cannot access settings before blog exists.");

# Create a blog....
$t->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    });

$t->get_ok( '/blog/1/settings' )
    ->status_is( 200 ); 

# Logout.
$t->reset_session;

$t->post_ok( '/register/open', form => { 
        name             => 'Ms Hax',
        email            => 'hacker@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->get_ok( '/blog/1/settings' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Cannot access settings for blog that isn\'t yours.' );

# Remove the alternative path.
$t->clear_tempdir;

done_testing;
