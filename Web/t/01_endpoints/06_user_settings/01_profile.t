#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the profile page displays the user's name and email
# address.
#
# 1. Create user and login.
# 2. Go to the profile page
# 3. Confirm the form fields contain the correct information
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $blog_id = $t->create_user
    ->get_ok( '/profile' )
    ->status_is( 200 )
    ->code_block(sub {
        my $self = shift;
        

        ok exists $self->stash->{form}->{name},  'Name exists in profile form.';
        ok exists $self->stash->{form}->{email}, 'Email address exists in profile form.';

        is $self->stash->{form}->{name},  $self->stash->{person}->name,  "Name is set correctly.";
        is $self->stash->{form}->{email}, $self->stash->{person}->email, "Email is set correctly.";
    });

done_testing;
