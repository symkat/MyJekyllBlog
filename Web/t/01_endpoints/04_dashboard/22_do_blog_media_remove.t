#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the media panel for the blog can be used
# to remove upload files.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the settings -> advanced config panel
# 4. Confirm the stash has the media_files arrayref.
# 5. Upload a file through the media panel
# 6. Confirm the file exists on disk
# 7. Confirm the file exists in the panel
# 8. Remove the file with the media form
# 9. Confirm the file doesn't exist on disk
# 10. Confirm the file doesn't exist in the panel
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

$t->get_ok( "/dashboard/blog/$blog_id/media" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{media_files}, 'We have media files in the stash.';
        is ref    $self->stash->{media_files}, 'ARRAY', 'We have media files in the stash as an arrayref.';
    })
    ->status_is( 200 );

# Upload the file
$t->post_ok( "/dashboard/blog/$blog_id/media", form => {
        upload => { content => 'Hello World', filename => 'hello-world.png' },
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/media" );

# Confirm the uploaded file exists on disk.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/assets/media/hello-world.png',
    'The media file was written to disk.';


# Confirm the uploaded file exists in the media panel.
$t->get_ok( "/dashboard/blog/$blog_id/media" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{media_files}, 'We have media files in the stash.';
        is ref    $self->stash->{media_files}, 'ARRAY', 'We have media files in the stash as an arrayref.';

        # Confirm the uploaded file exists now.
        is $self->stash->{media_files}->[0]->{url}, 'https://blog.example.com/assets/media/hello-world.png', "Expected URL for uploaded media.";
    })
    ->status_is( 200 );

# Remove the file
$t->post_ok( "/dashboard/blog/$blog_id/media/remove", form => {
        file => 'hello-world.png',
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/media" );

# Confirm the removed file doesn't exist on disk.
ok ! -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/assets/media/hello-world.png',
    'The media file was removed from disk.';


# Confirm the uploaded file exists in the media panel.
$t->get_ok( "/dashboard/blog/$blog_id/media" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{media_files}, 'We have media files in the stash.';
        is ref    $self->stash->{media_files}, 'ARRAY', 'We have media files in the stash as an arrayref.';

        # Confirm the uploaded file exists now.
        is scalar @{$self->stash->{media_files}}, 0, 'No media files listed on panel.';
    })
    ->status_is( 200 );

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
