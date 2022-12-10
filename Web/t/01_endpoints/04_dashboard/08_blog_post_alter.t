#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a blog post can be edited in the alter panel
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Make a new blog post.
# 4. Ensure that the blog post shows up in the blog listing.
# 5. Make sure that the raw file for the blog post exists / right content
# 6. Load the alter editor for that blog post.
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

$t->post_ok( "/dashboard/blog/$blog_id/post", form => {
        postTitle   => 'First Post!',
        postDate    => '2022-11-27 12:48:00 -0700',
        postContent => 'This is my first post',
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/posts" );

# See if we have the blog post entry on disk, then try to read the post we created and confirm it's correct.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/_posts/2022-11-27-first-post.markdown',
    'The new blog post was written to disk.';

is $t->app->jekyll( 'blog.example.com' )->get_post( '2022-11-27-first-post.markdown' )->headers->{title},
    'First Post!', 'The title of the post is correct.'; 

is $t->app->jekyll( 'blog.example.com' )->get_post( '2022-11-27-first-post.markdown' )->markdown,
    'This is my first post', 'The content of the post is correct.'; 

# Make an edit to the post
$t->get_ok( "/dashboard/blog/$blog_id/post/alter?mdfile=2022-11-27-first-post.markdown" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{post}->markdown, 'This is my first post', 'Post alter editor loaded post.';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
