#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the password change page exists.
#
# 1. Create user and login.
# 2. Go to the password page and confirm it exists.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

$t->create_user
    ->get_ok( '/password' )
    ->status_is( 200 );

done_testing;
