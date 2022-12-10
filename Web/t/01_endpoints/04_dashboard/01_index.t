#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the dashboard index page works as expected.
#
# Users must login to access this page.
#
# This page will include blogs in the stash.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

$t->get_ok('/dashboard')
    ->status_is( 302 )
    ->header_is( location => '/login', "Cannot access dashboard without login." );

$t->create_user
    ->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    })
    ->get_ok( '/dashboard' )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{blogs}->[0]->domain->name, 'blog.example.com', 'Found blog in listing on dashboard.';
    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
