#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that people panel can be seen by admins, but not 
# normal or anonymouse users.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure an unauthed user cannot access this.
$t->get_ok( '/admin/people' )
    ->status_is( 302 )
    ->header_is( location => '/login', 'Anonymouse users may not access the admin people panel.' );

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
    ->get_ok( '/admin/people' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Normal users may not access the admin people panel.' )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Check to ensure that the people array exists and fred is in it.
$t->get_ok( '/admin/people' )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{people}), 'ARRAY', 'Have an array ref for invite codes.';
        is scalar(@{$self->stash->{people}}), 1, 'Have one person entry';
        is $self->stash->{people}->[0]->email, 'fred@blog.com', 'Fred is the person entry.';
    });

done_testing();
