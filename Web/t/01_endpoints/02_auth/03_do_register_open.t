#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that the open registration system works as expected.
#
# 1. When the open registration system is disabled, attemps to use it will result
#    in the user being redirected to /register.
# 2. When the form is submitted with errors, the account is not created and those
#    errors are reported to the user.
# 3. When there are no errors, the user account is created and the user is logged in.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that this registration method is disabled.
$t->app->config->{register}{enable_open} = 0;

# Ensure that a user who has come to this page is redirected to the default registration system
$t->get_ok( '/register/open' )
    ->status_is( 302 )
    ->header_is( location => '/register' );

# Ensure that a user who submits this form in a naughty way is redirected to the default registration system
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->header_is( location => '/register' )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    });

# Make sure that this registration method is enabled.
$t->app->config->{register}{enable_open} = 1;

# Try creating an account with an error, ensure we get the error.
$t->post_ok( '/register/open', form => { 
        name     => 'fred',
        email    => 'fred@blog.com',
        password => 'SuperSecure',
        password_confirm => 'SuperFail',
    })->status_is( 302
    )->code_block( sub {
        is( shift->stash->{errors}->[0], 'Password and confirm password must match', 'Expected error thrown' );
    })->code_block( sub {
        is( shift->app->db->resultset('Person')->search( { name => 'fred'})->count, 0, 'No user created.');
    });

## Try creating a valid account, ensure it exists in the DB.
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
    });

done_testing();
