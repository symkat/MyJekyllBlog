#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the blog history panel for the blog can be viewed.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the blog history panel
# 4. Confirm the stash has the history arrayref.
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

$t->get_ok( "/dashboard/blog/$blog_id/history" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{history}, 'We have media files in the stash.';
        is ref    $self->stash->{history}, 'ARRAY', 'We have media files in the stash as an arrayref.';
    })
    ->status_is( 200 );

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
