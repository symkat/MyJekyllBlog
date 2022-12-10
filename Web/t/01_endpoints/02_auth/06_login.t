#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

my $t = Test::Mojo::MJB->new('MJB::Web');

##
# This test ensures that a user who hasn't logged in can access the login page.
###

$t->get_ok( '/login' )->status_is( 200 );

done_testing();
