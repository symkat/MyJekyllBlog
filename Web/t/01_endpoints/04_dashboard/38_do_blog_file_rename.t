#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that you can rename a file.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the files tab in the blog manager
# 4. Confirm the index.md file exists.
# 5. Confirm the not-index.md file does not exist.
# 6. Rename index.md to not-index.md
# 7. Confirm the index.md file does exist.
# 8. Confirm the not-index.md file does not exist.
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

$t->get_ok( "/dashboard/blog/$blog_id/files" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;

        ok exists $self->stash->{files},        'Have file listing.';
        is ref($self->stash->{files}), 'ARRAY', 'File listing is an array.';
    });

# Confirm index.md exists.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=index.md" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;
        ok exists $self->stash->{file_content}, 'Have file content.';
    });

# Confirm that index.md does not exist.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=not-index.md" )
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/files" )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{errors}->[0], 'Unable to load file.', "Unknown file results in error.";
    });

# Rename index.md to not-index.md 
$t->post_ok( "/dashboard/blog/$blog_id/file/rename", form => {
        file_name => 'index.md',
        file_path => "",
        new_name  => 'not-index.md',
        new_path  => "",
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/files?dir=");

# Confirm that index.md does not exist anymore.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=index.md" )
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/files" )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{errors}->[0], 'Unable to load file.', "Unknown file results in error.";
    });

# Confirm not-index.md does exist now.
$t->get_ok( "/dashboard/blog/$blog_id/file?name=not-index.md" )
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
