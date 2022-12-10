#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the subscription page works.
#
# 1. Create user and login.
# 2. Go to the subscription page
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $blog_id = $t->create_user
    ->get_ok( '/subscription' )
    ->status_is( 200 );

done_testing;
