#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

my $t = Test::Mojo::MJB->new('MJB::Web');

#==
# This test ensures that users can access the forgot password page.
#==

$t->get_ok( '/forgot' )
    ->status_is( 200 ); 

done_testing();
