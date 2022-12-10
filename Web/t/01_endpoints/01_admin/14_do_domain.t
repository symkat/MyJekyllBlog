#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that domains can be added through the admin panel.
#
# It creates an admin user, who then creates a domain name, and it confirms the
# domain name exists in the stash for the /admin/domains page.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

# Make sure an unauthed user cannot access this.
$t->get_ok( '/admin/alerts' )
    ->status_is( 302 )
    ->header_is( location => '/login', 'Anonymouse users may not access the admin panel.' );

# Register a user account and log into it.  
#
# A normal user should still not be allowed to view this page.
#
# Promote the user to an admin
$t->app->config->{register}{enable_open} = 1;
$t->post_ok( '/register/open', form => { 
        name             => 'fred',
        email            => 'fred@blog.com',
        password         => 'SuperSecure',
        password_confirm => 'SuperSecure',
    })
    ->status_is( 302 )
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })
    ->get_ok( '/admin/domains' )
    ->status_is( 302 )
    ->header_is( location => '/dashboard', 'Normal users may not access to domains.' )
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

# Add a domain.
$t->post_ok( '/admin/domain', form => { 
        domain_fqdn   => 'example-blog.com',
        ssl_challenge => 'http',
    })
    ->header_is( location => '/admin/domains' );

# Check to ensure that the domain name exists now.
$t->get_ok( '/admin/domains' )
    ->code_block( sub {
        my $self = shift;

        is ref($self->stash->{domains}), 'ARRAY', 'Have an array ref for domains';
        is $self->stash->{domains}->[0]->name, 'example-blog.com', 'Have an entry for the domain.';
    });

done_testing;

