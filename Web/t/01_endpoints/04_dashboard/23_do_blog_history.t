#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the blog history panel for the blog can be used to
# restore the state of an old commit.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the blog history panel
# 4. Confirm the stash has the history arrayref and get the current commit id.
# 5. Upload a media file and confirm its on the disk
# 6. Use the history panel to restore the version before the media file
# 7. Confirm the media file has been purged
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


my $commit = $t->get_ok( "/dashboard/blog/$blog_id/history" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{history}, 'We have media files in the stash.';
        is ref    $self->stash->{history}, 'ARRAY', 'We have media files in the stash as an arrayref.';
    })
    ->status_is( 200 )
    ->stash->{history}->[0]->{commit};

# Upload the file
$t->post_ok( "/dashboard/blog/$blog_id/media", form => {
        upload => { content => 'Hello World', filename => 'hello-world.png' },
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/media" );

# Confirm the uploaded file exists on disk.
ok -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/assets/media/hello-world.png',
    'The media file was written to disk.';


# Restore the old commit 
$t->post_ok( "/dashboard/blog/$blog_id/history", form => {
        commit_hash => $commit,
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/history" );

# Confirm the uploaded file purged from disk.
ok ! -f $t->app->jekyll( 'blog.example.com' )->root . '/blog.example.com/assets/media/hello-world.png',
    'The media file was removed from disk.';
#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
