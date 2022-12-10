#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a blog page can be removed.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Make a new blog page.
# 4. Make sure that the raw file for the blog page exists / right content
# 6. Remove the page.
# 7. Confirm the page has been removed.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $blog_id = $t->create_user
    ->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    })
    ->get_ok( '/dashboard' )
    ->stash->{blogs}->[0]->id;

$t->get_ok( "/dashboard/blog/$blog_id" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        ok exists $self->stash->{blog}, "The blog loads!";
        is $self->stash->{blog}->domain->name, 'blog.example.com', "Correct domain name for id.";
    });

$t->post_ok( "/dashboard/blog/$blog_id/page", form => {
        pagePath    => 'contact',
        pageTitle   => 'Contact Page',
        pageHeaders => "title: Contact Page\nlayout: page\n",
        pageContent => 'This is my contact page',
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/pages" );

# See if we have the blog post entry on disk, then try to read the post we created and confirm it's correct.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/contact.markdown',
    'The new blog page was written to disk.';

# Remove the page
$t->post_ok( "/dashboard/blog/$blog_id/page/remove", form => {
        file      => '/contact.markdown',
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/pages" );

ok ! -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/contact.markdown',
    'The new blog page was removed from disk.';

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
