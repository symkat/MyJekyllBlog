#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test will ensure that a blog can be deleted.
#
# It will create an account, then a blog, then it will confirm
# the jekyll root and database rows exists for it.
# 
# Then it will delete the blog, and confirm the jekyll root has
# been removed, and the database rows no longer exist.
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

# Get the disk path for the repo for the blog.
my $repo_path = $t->app->jekyll('blog.example.com')->repo_path;

# Ensure the disk path exists.
ok -d $repo_path, 'The repo path exists for the blog before being deleted.';

# Ensure the DB record exists.
ok $t->app->db->blog( 1 ), "Have a blog record for blog id 1";

# Remove the blog.
$t->post_ok( '/blog/1/remove', form => { } )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Successful delete goes to the dashboard.' );

# Ensure the disk path doesn't exist.
ok ! -d $repo_path, 'The repo path doesn\'t exist for the blog after being deleted.';

# Ensure the DB record doesn't exist.
ok ! $t->app->db->blog( 1 ), "Don't have a blog record for blog id 1";

# Remove the alternative path.
$t->clear_tempdir;

done_testing;