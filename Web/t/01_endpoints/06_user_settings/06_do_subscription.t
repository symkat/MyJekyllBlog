#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# Ensure the handler exists for do_subscription.
#
# Don't actually run it, since it depends on the stripe-backend, and
# that is outside of the scope of these tests.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

ok $t->app->routes->find( 'do_subscription' ), 'Have a route for do_subscription';
is $t->app->routes->find( 'do_subscription' )->methods->[0], 'POST', 'Is a post handler.';

done_testing();
