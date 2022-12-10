#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that the admin index page works as expected.
#
# Anonymous users are redirected to login.
#
# Users who are not admins are redirected to /dashboard
#
# Admins are redirected to /admin/people since we don't have an index page currently.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Ensure that a user who hasn't logged in cannot access this page.
$t->get_ok( '/admin' )
    ->status_is( 302 )
    ->header_is( location => '/login' );

# Register a user account and log into it.  A normal user should still not be allowed to view this page.

$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })->status_is( 302 
    )->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })->code_block( sub {
        is( shift->app->db->resultset('Person')->search( { name => 'fred'})->count, 1, 'User created.');
    })->get_ok( '/'
    )->code_block( sub {
        is(shift->stash->{person}->name, 'fred', 'Got the fred after login...');
    })->get_ok( '/admin' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Redirected user to dashboard when not an admin' );

# Promote fred to an admin and then ensure that the /admin page correctly redirects him to /admin/people 
$t->get_ok( '/'
    )->code_block( sub {
        my $self = shift;
        is($self->stash->{person}->name, 'fred', 'Fred is still logged in');
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    })->get_ok( '/admin' )
    ->status_is( 302 )
    ->header_is( location => '/admin/people', 'Admin index redirects to /admin/people for valid admin account' );

done_testing();
