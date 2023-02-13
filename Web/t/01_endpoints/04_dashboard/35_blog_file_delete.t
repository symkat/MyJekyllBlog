#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the blog manager has a files tab that functions as a file browser.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the files tab in the blog manager
# 4. Confirm the delete controller gives a 200 for a valid file.
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

$t->get_ok( "/dashboard/blog/$blog_id/file/delete?name=index.md" )
    ->status_is( 200 );
#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;