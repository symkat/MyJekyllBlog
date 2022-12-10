#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the settings panel for the blog can be viewed.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Go to the settings panel
# 4. Confirm the stash values.
# 5. Change all of the values with the settings update
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
$t->get_ok( "/dashboard/blog/$blog_id/settings" )
    ->code_block(sub {
        my $self = shift;
        ok exists $self->stash->{form}->{title}, 'There is a title';
        ok exists $self->stash->{form}->{desc},  'There is a description';
        ok exists $self->stash->{form}->{email}, 'There is an email';
    })
    ->status_is( 200 );

# Make the update and then confirm the changes.
$t->post_ok( "/dashboard/blog/$blog_id/settings", form => {
        configTitle => 'Test title',
        configDesc  => 'Test description',
        configEmail => 'test@blog.com',
    })
    ->status_is( 302 )
    ->header_is( location => "/dashboard/blog/$blog_id/settings" )
    ->get_ok( "/dashboard/blog/$blog_id/settings" )
    ->status_is( 200 )
    ->code_block(sub {
        my $self = shift;
        is $self->stash->{form}->{title}, 'Test title',       'The correct title is set';
        is $self->stash->{form}->{desc},  'Test description', 'The correct description is set';
        is $self->stash->{form}->{email}, 'test@blog.com',    'The correct email is set';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
