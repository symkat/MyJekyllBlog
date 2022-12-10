#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the config panel for the blog can be used to
# change the config/settings.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the config panel
# 4. Confirm the stash values.
# 5. Change all of the values with the config update
# 6. Confirm the changes took effect.
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

# Check the settings page and confirm the settings values exist.
$t->get_ok( "/dashboard/blog/$blog_id/config" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{form}->{config}, 'There is a config';
    })
    ->status_is( 200 );

# Make the update and then confirm the changes.
$t->post_ok( "/dashboard/blog/$blog_id/config", form => {
        blogConfig => "title: Test title",
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/config" )
    ->get_ok( "/dashboard/blog/$blog_id/config" )
    ->status_is( 200 )
    ->code_block(sub {
        my $self = shift;
        is $self->stash->{form}->{config}, "---\ntitle: Test title\n", 'The correct config is set';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
