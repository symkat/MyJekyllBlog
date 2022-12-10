#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that invite codes can be removed through the admin panel.
#
# It creates an admin user, who then creates an invite code, and it confirms the
# invite code exists in the stash for the /admin/invites page, then it deletes the
# invite and confirms it is no longer available.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure an unauthed user cannot access this.
$t->get_ok( '/admin/invites' )
    ->status_is( 302 )
    ->header_is( location => '/login', 'Anonymouse users may not access the admin invites panel.' );

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
    ->get_ok( '/admin/invites' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Normal users may not access the admin invites panel.' )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Add an invite code.
$t->post_ok( '/admin/invite', form => { 
        code => 'my-code',
        is_multi_use => 0,
    })
    ->header_is( location => '/admin/invites' );

# Check to ensure that the invite code exists now, and remove it.
$t->get_ok( '/admin/invites' )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{invites}), 'ARRAY', 'Have an array ref for invite codes.';
        is $self->stash->{invites}->[0]->code, 'my-code', 'Have an entry for the invite code.';

        # Now we will remove the invite code.
        $t->post_ok( '/admin/invite/remove', form => { iid => $self->stash->{invites}->[0]->id })
            ->header_is( location => '/admin/invites' );
    });

# Confirm the invite code has been removed.
$t->get_ok( '/admin/invites' )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{invites}), 'ARRAY', 'Have an array ref for invite codes';
        is scalar(@{$self->stash->{invites}}), 0, 'Invite code was removed.';
    });

done_testing;
