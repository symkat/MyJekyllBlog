#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a blog can be created with a hosted domain.
#
# A user account will be registered, promoted to admin, and create a hosted
# domain for 'example.com'.  The user will then create a blog on 
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
    ->status_is( 302 )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Add a hosted domain
$t->post_ok( '/admin/domain', form => { 
        domain_fqdn   => 'example.com',
        ssl_challenge => 'http',
    })
    ->header_is( location => '/admin/domains' );

# Create a blog with the hosted domain method....
$t->post_ok( '/blog/domain', form => {
        hosted_subdomain => 'blog',
        hosted_domain_id => 1,
        calling_route    => 'show_blog_domain_hosted',
    });

sleep 1; # Give a moment for the files to all write from the last step.

# See if we have the blog directory and index.markdown file.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/index.md', 
    'Have an index file for the blog!';

# Remove the alternative path.
$t->clear_tempdir;

done_testing;
