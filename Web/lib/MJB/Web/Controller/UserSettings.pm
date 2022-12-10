package MJB::Web::Controller::UserSettings;
use Mojo::Base 'Mojolicious::Controller', -signatures;

#=====
# This file handles the My Info / User Settings panels.
#
# It is a controller, the template files live in templates/user_settings.
#=====

#==
# GET /profile | show_profile | templates/user_settings/profile.html.ep
#==
sub profile ( $c ) {
    # Set the form values from the DB if they don't exist from the POST handler.
    $c->stash->{form}->{name}  ||= $c->stash->{person}->name;
    $c->stash->{form}->{email} ||= $c->stash->{person}->email;
}

#==
# POST /profile | do_profile
#       name     | The value to set for the account name
#       email    | The value to set for the account email
#       password | The current password, used to authenticate this request.
#
# This route will change the user's name or email address.  They are required
# to submit their current password to make these changes.
#==
sub do_profile ( $c ) {
    my $name     = $c->stash->{form}->{name}     = $c->param('name');
    my $email    = $c->stash->{form}->{email}    = $c->param('email');
    my $password = $c->stash->{form}->{password} = $c->param('password');
    
    # Populate errors if we don't have values.
    push @{$c->{stash}->{errors}}, "You must enter your name"     unless $name; 
    push @{$c->{stash}->{errors}}, "You must enter your email"    unless $email;
    push @{$c->{stash}->{errors}}, "You must enter your password" unless $password;

    # Bail out if we have errors now.
    return $c->redirect_error( 'show_profile' )
        if $c->stash->{errors};

    $c->stash->{person}->auth_password->check_password( $password )
        or push @{$c->stash->{errors}}, "You must enter your current login password correctly.";
    
    # Bail out if we have errors now.
    return $c->redirect_error( 'show_profile' )
        if $c->stash->{errors};

    $c->stash->{person}->name( $name );
    $c->stash->{person}->email( $email );

    $c->stash->{person}->update;

    # Let the user know the action was successful.
    $c->flash( confirmation => "Your records have been updated." );
    $c->redirect_to( $c->url_for( 'show_profile' ) );
}

#==
# GET /change_password | show_change_password | templates/user_settings/change_password.html.ep
#==
sub change_password ( $c ) { 

}

#==
# POST /change_password | do_change_password
#       password         | The current password, used to authenticate this request.
#       new_password     | The new password to set for the account.
#       password_confirm | Confirmation of the new password, it must match.
#
# This route will update the user's password.
#==
sub do_change_password ( $c ) {
    # Get the values the user gave for the password change.
    my $password = $c->stash->{form}->{password}         = $c->param('password');
    my $new_pass = $c->stash->{form}->{new_password}     = $c->param('new_password');
    my $confirm  = $c->stash->{form}->{password_confirm} = $c->param('password_confirm');

    # Populate errors if we don't have values.
    push @{$c->{stash}->{errors}}, "You must enter your current password"               unless $password; 
    push @{$c->{stash}->{errors}}, "You must enter your new password"                   unless $new_pass;
    push @{$c->{stash}->{errors}}, "You must enter your new password again to confirm"  unless $confirm;
    
    # Bail out if we have errors now.
    return $c->redirect_error( 'show_change_password' )
        if $c->stash->{errors};

    $c->stash->{person}->auth_password->check_password( $password )
        or push @{$c->stash->{errors}}, "You must enter your current login password correctly.";
    
    # Bail out if we have errors now.
    return $c->redirect_error( 'show_change_password' )
        if $c->stash->{errors};
    
    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $new_pass eq $confirm;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($new_pass) >= 8;
    
    # Bail out if we have errors now.
    return $c->redirect_error( 'show_change_password' )
        if $c->stash->{errors};

    # We can update the password now.
    $c->stash->{person}->auth_password->update_password($new_pass);

    # Let the user know the action was successful.
    $c->flash( confirmation => "Your password was updated." );
    $c->redirect_to( $c->url_for( 'show_change_password' ) );
}

sub subscription ($c) {
    my $status = $c->param('status');

    # No status=, the user themself requested this page.
    if ( ! $status ) {
        return;
    }

    # Status isn't successful, tell the user they could try agan.
    if ( $status ne 'success' ) {
        push @{$c->stash->{errors}}, "Subscription wasn't successful.";
        return;
    }

    my $session_id = $c->param('session_id');

    my $customer_id = $c->ua->get( $c->config->{stripe}->{backend} . '/stripe/session-to-customer?session_id=' . $session_id )->result->json->{customer_id};

    # Store the customer id along side the user in the DB.
    if ( $customer_id ) {
        $c->db->storage->schema->txn_do( sub {
            $c->stash->{person}->subscription->stripe_customer_id( $customer_id );
            $c->stash->{person}->subscription->is_valid( 1 );
            $c->stash->{person}->subscription->update;
        });
    }

    $c->flash( confirmation => "Thank you for signing up!" );
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

# Send to stripe to signup for the subscription
sub do_subscription ($c) {
    my $lookup_key = $c->param('lookup_key');
    my $url = $c->ua->get( $c->config->{stripe}->{backend} . '/stripe/get-checkout-link?lookup_key=' . $lookup_key )->result->json->{url};

    $c->redirect_to( $url );
}

# Send to stripe to manage the subscription
sub do_subscription_manage ($c) {
    my $url = $c->ua->get( $c->config->{stripe}->{backend} . '/stripe/get-portal-link?customer_id=' . $c->stash->{person}->subscription->stripe_customer_id )->result->json->{url};

    $c->redirect_to( $url );
}

1;

