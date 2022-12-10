#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

my $t = Test::Mojo::MJB->new('MJB::Web');

# Contact Page Exists 
$t->get_ok( '/contact' )
    ->status_is( 200 );

done_testing();
