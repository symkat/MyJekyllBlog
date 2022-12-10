#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test file ensures that notes can be added to a user's account.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

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
    ->code_block( sub {
        is( scalar(@{shift->stash->{errors}}), 0, 'No errors' );
    })
    ->get_ok( '/' )
    ->code_block( sub {
        my $self = shift;
        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted fred to an admin' );
    });

$t->post_ok( '/admin/person/1/note', form => { 
        content => "Hello World!",
    })
    ->status_is( 302 )
    ->header_is( location => '/admin/person/1' )
    ->get_ok( '/admin/person/1' )
    ->code_block( sub {
        my $self = shift;

        # We should have fred loaded into the profile...
        is $self->stash->{notes}->[0]->content, 'Hello World!', 'The note was saved in the profile.';
    });

done_testing();
