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
# 3. Go to the files tab in the blog manager, confirm listing exists.
# 4. Ensure that a known file lists correctly.
# 5. Ensure that an unknown file does not list.
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

# Show files.
$t->get_ok( "/dashboard/blog/$blog_id/files" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;

        ok exists $self->stash->{files},        'Have file listing.';
        is ref($self->stash->{files}), 'ARRAY', 'File listing is an array.';
    });

# Load a file that exists and confirm the contents and status.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=index.markdown" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        ok exists $self->stash->{file_content}, 'Have file content.';
    });

# Load a file that doesn't exist, confirm the error redirect and message.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=this-file-does-not-exist" )
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/files" )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{errors}->[0], 'Unable to load file.', "Unknown file results in error.";
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;

