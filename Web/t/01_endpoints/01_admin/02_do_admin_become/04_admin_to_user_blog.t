#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test confirms that an admin can login to a user account through the
# admin become functionality.
#
# 1. Create a user and record the id.
# 2. Create a blog for that user and record the id.
# 3. Log out of the user account.
# 4. Make a new user account, promote it to admin, and login.
# 5. Try to use admin_become with userid and blogid and confirm 
#    I am logged into the blog manager for that blog as that user.
# 6. Logout and confirm I am logged in under the admin account.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $user_id = $t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->stash->{person}->id;

my $blog_id = $t->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    })
    ->get_ok( '/dashboard' )
    ->stash->{blogs}->[0]->id;

# Logout
$t->get_ok( '/logout' )
    ->reset_session;

# Make a new user, promote to admin
my $admin_id = $t->create_user
    ->get_ok( '/profile' )
    ->code_block( sub {
        my $self = shift;

        $self->stash->{person}->is_admin( 1 );
        ok( $self->stash->{person}->update, 'Promoted user to an admin' );
    })->stash->{person}->id;

# Try to become the first user that was created, confirm we do, and that we
# are redirected to the blog management page for the blog.
$t->post_ok( '/admin', form => {
        uid => $user_id,
        bid => $blog_id,
    })
    ->header_is( location => "/dashboard/blog/$blog_id" )
    ->status_is( 302 )
    ->get_ok( "/dashboard/blog/$blog_id" )
    ->code_block(sub {
        is shift->stash->{person}->id, $user_id, 'Admin has become target user';
    });

# Logout and confirm the user id resets back to the admin one.
$t->get_ok( '/logout' )
    ->status_is( 302 )
    ->header_is( location => '/admin' )
    ->get_ok( '/admin' )
    ->code_block(sub {
        is shift->stash->{person}->id, $admin_id, 'Admin has become self again';
    });



done_testing;
