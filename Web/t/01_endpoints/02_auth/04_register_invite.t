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
# 2. When the invite registration system is enabled, the page displayes.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure that this registration method is disabled.
$t->app->config->{register}{enable_invite} = 0;

# Ensure that a user who has come to this page is redirected to the default registration system
$t->get_ok( '/register/invite' )
    ->status_is( 302 )
    ->header_is( location => '/register' );

# Make sure that this registration method is enabled.
$t->app->config->{register}{enable_invite} = 1;

# Ensure that the invite registration page displays when it is enabled.
$t->get_ok( '/register/invite' )
    ->status_is( 200 );

done_testing();
