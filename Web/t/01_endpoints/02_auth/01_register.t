#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that the open registration redirect system works as expected.
#
# The value of config->{register}{default} controls the redirect:
#
# invite -> /registration/invite
# open   -> /registration/open
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Ensure both registration systems are enabled.
$t->app->config->{register}{enable_open}   = 1;
$t->app->config->{register}{enable_invite} = 1;

# Check about redirects to the invite system working correctly. 
$t->app->config->{register}{default} = 'invite';

$t->get_ok( '/register' )
    ->status_is( 302 )
    ->header_is( location => '/register/invite' );

# Check about redirects to the open system working correctly. 
$t->app->config->{register}{default} = 'open';

# Ensure that a user who has come to this page is redirected to the default registration system
$t->get_ok( '/register' )
    ->status_is( 302 )
    ->header_is( location => '/register/open' );

done_testing();
