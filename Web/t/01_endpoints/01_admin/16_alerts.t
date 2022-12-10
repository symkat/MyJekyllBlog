#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that the /admin/alerts page displays alerts.
#
# When a user account is created, an alert about it is recorded.  I will check for that
# alert existing.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure an unauthed user cannot access this.
$t->get_ok( '/admin/alerts' )
    ->status_is( 302 )
    ->header_is( location => '/login', 'Anonymouse users may not access the admin panel.' );

# Register a user account and log into it.  
#
# A normal user should still not be allowed to view this page.
#
# Promote the user to an admin
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })
    ->get_ok( '/admin/alerts' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Normal users may not access to admin alerts.' )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Check that we have an alert about the account that has just been created,
$t->get_ok( '/admin/alerts' )
    ->code_block( sub {
        my $self = shift;
        is $self->stash->{alerts}->[0]->content, 'An account was created for fred@blog.com',
            'We have an alert for the user account created!';
    });

done_testing();
