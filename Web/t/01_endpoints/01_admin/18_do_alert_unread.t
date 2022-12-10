#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that we can mark alerts as unread.
#
# It will be the same as the previous test, but extended to check
# the additional unread controller.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Create and promote a user to an admin
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Find the alert.
my ( $alert ) = $t->app->db->system_notes->all;

ok $alert, "I have the alert.";
is $alert->is_read, 0, "The alert is marked as unread.";


# Submit the form to mark it as read.
$t->post_ok( '/admin/alert/read', form => { nid => $alert->id })
    ->status_is( 302 )
    ->header_is( location => '/admin/alerts' );

# Check that the alert is now marked as read.
is $t->app->db->system_note($alert->id)->is_read, 1, "The alert was marked as read.";

# Submit the form to mark it as unread.
$t->post_ok( '/admin/alert/unread', form => { nid => $alert->id })
    ->status_is( 302 )
    ->header_is( location => '/admin/alerts' );

# Check that the alert is now marked as unread.
is $t->app->db->system_note($alert->id)->is_read, 0, "The alert was marked as unread.";

done_testing();
