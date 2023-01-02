#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a blog can be created with an owned domain.
#
# A user account will be registered, and the user will create a blog on 
# blog.example.com, and then it will be confirmed that a blog exists with its
# index page.
#
# Note: During testing ->jekyll uses an alternative root path to store repos at.
#       When using ->jekyll in tests, you MUST call $t->clear_tempdir when you are
#       done testing to remove the altrernative jekyll root.
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
    ->status_is( 302 );

# Create a blog....
$t->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    });

sleep 1; # Give a moment for the files to all write from the last step.

# See if we have the blog directory and index.markdown file.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/index.markdown', 
    'Have an index file for the blog!';

# Remove the alternative path.
$t->clear_tempdir;

done_testing;
