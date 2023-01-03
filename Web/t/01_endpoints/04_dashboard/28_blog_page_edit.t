#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that a blog page can be opened in the editor panel.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Make a new blog page.
# 4. Open the editor page with this file loaded and confirm the file
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

$t->get_ok( "/dashboard/blog/$blog_id/page/edit?file=/contact.markdown" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{blog_page}->markdown,         'This is my contact page', 'Have expected content for page';
        is $self->stash->{blog_page}->headers->{title}, 'Contact Page',            'Have expected title for page';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
