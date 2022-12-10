#!/usr/bin/env perl
use MJB::Web::Test;
use Mojo::File;
use YAML::XS qw( Load );

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the settings for a blog will take effect as part
# of the blog setup.
#
# It will create a blog, then submit the settings page.  Once it has, it will
# load the config file that was created and confirm the updates.
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

# Make the settings for the blog...
$t->post_ok( '/blog/1/settings', form => {
        configTitle => 'Installed By Bot',
        configDesc  => 'A blog about robot dogs.'
    })
    ->status_is( 302 );

# Confirm the settings were written to disk....
ok my $config = Load(
    Mojo::File->new( $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/_config.yml' )->slurp
), 'Load blog config file from disk.';

# Confirm the changes were written.
is $config->{title},       'Installed By Bot',         "Confirm config title was updated.";
is $config->{description}, 'A blog about robot dogs.', "Confirm config description was updated.";

# Remove the alternative path.
$t->clear_tempdir;

done_testing;
