#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

my $t = Test::Mojo::MJB->new('MJB::Web');

# Home Page Exists 
$t->get_ok( '/' )
    ->status_is( 200 );

done_testing();
