#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that the invite registration system works as expected.
#
# 1. When the invite registration system is disabled, attemps to use it will result
#    in the user being redirected to /register.
# 2. When the form is submitted without an invite code, the account is not created and 
#    an error is reported to the user.
# 3. When there is a valid invite code, the user account is created and the user is logged in.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that this registration method is disabled.
$t->app->config->{register}{enable_invite} = 0;

# Ensure you cannot register an account with the invite system when it is disabled.
$t->post_ok( '/register/invite', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
        invite_code      => 'invite-code',
    })
    ->status_is( 302 )
    ->header_is( location => '/register' );

# Make sure that this registration method is disabled.
$t->app->config->{register}{enable_invite} = 1;

# Trying to register an account without a valid invite code will fail.
$t->post_ok( '/register/invite', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
        invite_code      => 'invite-code',
    })
    ->status_is( 302 )
    ->header_is( location => '/register/invite' )
    ->code_block( sub {
        my $self = shift;
        is( scalar(@{$self->stash->{errors}}), 1, 'Got an expected error.' );
        is( $self->stash->{errors}->[0], 'That invite code is not valid.', 'Expected error.' );
    });

# Create an invite code.
$t->app->db->invites->create({ code => 'invite-code' });

# Register an account with a valid invite code. 
$t->post_ok( '/register/invite', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
        invite_code      => 'invite-code',
    })
    ->status_is( 302 )
    ->header_is( location => '/dashboard' )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    });

done_testing();
