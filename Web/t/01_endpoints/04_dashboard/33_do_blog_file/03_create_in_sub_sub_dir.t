#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that blog files can be created.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the files tab in the blog manager, confirm listing exists.
# 4. Ensure that a file does not exist.
# 5. Create that file.
# 6. Confirm the newly created file does exist.
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


# Load a file that doesn't exist, confirm the error redirect and message.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=docs/files/mytest.md" )
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/files" )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{errors}->[0], 'Unable to load file.', "Unknown file results in error.";
    });

# Create a directory
$t->post_ok( "/dashboard/blog/$blog_id/file", form => {
        file_name => 'docs/files',
        file_type => 'directory',
        file_path => "",
    })
    ->status_is( 302 );
    
# Create a directory
#$t->post_ok( "/dashboard/blog/$blog_id/file", form => {
#        file_name => 'files',
#        file_type => 'directory',
#        file_path => "docs",
#    })
#    ->status_is( 302 );

# Post the file to be created.
$t->post_ok( "/dashboard/blog/$blog_id/file", form => {
        file_name => 'mytest',
        file_type => '.md',
        file_path => "docs/files",
    })
    ->status_is( 302 );

# Load a file that exists and confirm the contents and status.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=docs/files/mytest.md" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        ok exists $self->stash->{file_content}, 'Have file content.';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;

