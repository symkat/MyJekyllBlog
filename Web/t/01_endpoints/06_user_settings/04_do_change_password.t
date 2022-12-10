#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the password change page works as expected.
#
# 1. Create user and login.
# 2. Go to the password page and confirm it exists.
# 3. Change the password for the user account
# 4. Logout and confirm being logged out.
# 5. Login with the new credentials and confirm being logged in.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Create a user and confirm the password page exists.
$t->create_user
    ->get_ok( '/password' )
    ->status_is( 200 );

# Change the password.
$t->post_ok( '/password', form => {
        password         => $t->stash->{person}->name,
        new_password     => 'Test-Password',
        password_confirm => 'Test-Password',
    })
    ->status_is( 302 )
    ->header_is( location => '/password' );

# Grab the email we'll use for logging back in.
my $email = $t->stash->{person}->email;

# Logout
$t->get_ok( '/logout' );

$t->get_ok( '/dashboard' )
    ->status_is( 302 )
    ->header_is( location => '/login', "User is logged out." );

# Try to login with the new password.
$t->post_ok( '/login', form => { 
        email            => $email,
        password         => 'Test-Password',
    })->status_is( 302 
    )->header_is( location => '/dashboard', 'Login redirected to dashboard' )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    });

done_testing;
