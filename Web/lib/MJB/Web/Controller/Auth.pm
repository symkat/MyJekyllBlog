package MJB::Web::Controller::Auth;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;
use DateTime;

#=====
# This file handles the the user registration, login/logout,
# and resetting a forgotten password.
#
# It is a controller, the template files live in templates/auth.
#=====

#==
# GET /register | show_register | templates/auth/register.html.ep
#
# Send the user to whatever the default registration system is.
#==
sub register ( $c ) {
    return $c->redirect_to( $c->url_for( 'show_dashboard' ) )
        if exists $c->stash->{person} and $c->stash->{person}->id;

    return $c->redirect_to( $c->url_for( 'show_register_stripe' ) )
        if $c->config->{register}{default} eq 'stripe';
    
    return $c->redirect_to( $c->url_for( 'show_register_invite' ) )
        if $c->config->{register}{default} eq 'invite';

    return $c->redirect_to( $c->url_for( 'show_register_open' ) )
        if $c->config->{register}{default} eq 'open';
    
    # No default registration system.
    return $c->redirect_to( $c->url_for( 'show_homepage' ) );
}

#==
# GET /register/open | show_register_open | templates/auth/register_open.html.ep
#==
sub register_open ( $c ) {
    # Don't allow this user registration method unless register.enable_open is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_open};
}

#==
# POST /register/open | do_register_open
#       name             | The name of the person who is registering an account
#       email            | The email address of the person registering the account
#       password         | The password they would like to use
#       password_confirm | The same password again, in case they don't know it for sure
#
# Create an account for the user and login to that account once it has been created.
#==
sub do_register_open ( $c ) {
    my $name      = $c->stash->{form}->{name}             = $c->param('name');
    my $email     = $c->stash->{form}->{email}            = $c->param('email');
    my $password  = $c->stash->{form}->{password}         = $c->param('password');
    my $p_confirm = $c->stash->{form}->{password_confirm} = $c->param('password_confirm');

    # Don't allow this user registration method unless register.enable_open is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_open};

    push @{$c->stash->{errors}}, "Name is required"             unless $name;
    push @{$c->stash->{errors}}, "Email is required"            unless $email;
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $p_confirm;
    
    return $c->redirect_error( 'show_register' )
        if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $p_confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    push @{$c->stash->{errors}}, "That email address is already registered."
        if $c->db->people( { email => $email } )->count;
    
    return $c->redirect_error( 'show_register_open' )
        if $c->stash->{errors};

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email     => $c->param('email'),
                name      => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));

            # Notify the system about the new account.
            $c->db->system_notes->create({
                source => 'User Registration (Open)',
                content => 'An account was created for ' . $person->email,
            });

            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
    };
    
    return $c->redirect_error( 'show_register_open' )
        if $c->stash->{errors};

    # Log the user in and send them to the dashboard.
    $c->session->{uid} = $person->id;
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

#==
# GET /register/invite | show_register_invite | templates/auth/register_invite.html.ep
#==
sub register_invite ( $c ) {
    $c->stash->{form}->{invite_code} ||= $c->param('code');
    
    # Don't allow this user registration method unless register.enable_invite is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_invite};
}

#==
# POST /register/invite | do_register_invite
#       name             | The name of the person who is registering an account
#       email            | The email address of the person registering the account
#       password         | The password they would like to use
#       password_confirm | The same password again, in case they don't know it for sure
#       invite           | A valid invite code
#
# Create an account for the user and login to that account once it has been created.
#
# If an invite code is used and is only valid once, it will be updated so it may no longer be used.
#==
sub do_register_invite ( $c ) {
    my $name      = $c->stash->{form}->{name}             = $c->param('name');
    my $email     = $c->stash->{form}->{email}            = $c->param('email');
    my $password  = $c->stash->{form}->{password}         = $c->param('password');
    my $p_confirm = $c->stash->{form}->{password_confirm} = $c->param('password_confirm');
    my $invite    = $c->stash->{form}->{invite_code}      = $c->param('invite_code');

    # Don't allow this user registration method unless register.enable_invite is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_invite};

    push @{$c->stash->{errors}}, "Name is required"             unless $name;
    push @{$c->stash->{errors}}, "Email is required"            unless $email;
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $p_confirm;
    push @{$c->stash->{errors}}, "Invite code is required"      unless $invite;

    return $c->redirect_error( 'show_register_invite' )
        if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $p_confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    push @{$c->stash->{errors}}, "That email address is already registered."
        if $c->db->people( { email => $email } )->count;
    
    push @{$c->stash->{errors}}, "That invite code is not valid."
        unless $c->db->invites( { code => $invite, is_active => 1 } )->count >= 1;
    
    return $c->redirect_error( 'show_register_invite' )
        if $c->stash->{errors};

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email     => $c->param('email'),
                name      => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));

            # Notify the system about the new account.
            $c->db->system_notes->create({
                source => 'User Registration (Invite)',
                content => 'An account was created for ' . $person->email,
            });

            # If a one-time use invite code was used, invalidate it.
            my $invite_record = $c->db->invites( { code => $invite, is_active => 1 } )->first;
            if ( $invite_record->is_one_time_use ) {
                $invite_record->is_active( 0 );
                $invite_record->update;
            }
            
            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
    };
    
    return $c->redirect_error( 'show_register_invite' )
        if $c->stash->{errors};

    # Log the user in and send them to the dashboard.
    $c->session->{uid} = $person->id;
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

#==
# GET /register/stripe | show_register_stripe | templates/auth/register_stripe.html.ep
#==
sub register_stripe ( $c ) {
    # Don't allow this user registration method unless register.enable_open is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_stripe};
}

#==
# POST /register/stripe | do_register_stripe
#       name             | The name of the person who is registering an account
#       email            | The email address of the person registering the account
#       password         | The password they would like to use
#       password_confirm | The same password again, in case they don't know it for sure
#
# Create an account for the user and login to that account once it has been created.
#==
sub do_register_stripe ( $c ) {
    my $name      = $c->stash->{form}->{name}             = $c->param('name');
    my $email     = $c->stash->{form}->{email}            = $c->param('email');
    my $password  = $c->stash->{form}->{password}         = $c->param('password');
    my $p_confirm = $c->stash->{form}->{password_confirm} = $c->param('password_confirm');

    # Don't allow this user registration method unless register.enable_open is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_stripe};

    push @{$c->stash->{errors}}, "Name is required"             unless $name;
    push @{$c->stash->{errors}}, "Email is required"            unless $email;
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $p_confirm;
    
    return $c->redirect_error( 'show_register_stripe' )
        if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $p_confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    push @{$c->stash->{errors}}, "That email address is already registered."
        if $c->db->people( { email => $email } )->count;
    
    return $c->redirect_error( 'show_register_stripe' )
        if $c->stash->{errors};

    my $person = try {
        $c->db->storage->schema->txn_do( sub {
            my $person = $c->db->resultset('Person')->create({
                email      => $c->param('email'),
                name       => $c->param('name'),
            });
            $person->new_related('auth_password', {})->set_password($c->param('password'));

            # Create the subscription.
            $person->create_related('subscription', {});

            # Notify the system about the new account.
            $c->db->system_notes->create({
                source => 'User Registration (Stripe)',
                content => 'An account was created for ' . $person->email,
            });

            return $person;
        });
    } catch {
        push @{$c->stash->{errors}}, "Account could not be created: $_";
    };
    
    return $c->redirect_error( 'show_register_stripe' )
        if $c->stash->{errors};

    # Log the user in asnd then send themn to the payment page.
    $c->session->{uid} = $person->id;
    $c->redirect_to( 
        $c->ua->get( $c->config->{stripe}->{backend} . '/stripe/get-checkout-link?lookup_key=' . $c->config->{stripe}->{lookup_key} )->result->json->{url}
    );
}

#==
# GET /register/stripe/pay | show_register_stripe_pay | N/A
#
# Once a user has registered in the strip work flow, they will need to pay
# for their account before it is enabled.  This route will bring them to the
# stripe subscription payment page -- in case it failed the first time.
#==
sub register_stripe_pay ( $c ) {
    # Don't allow this user registration method unless register.enable_open is true.
    return $c->redirect_to( $c->url_for( 'show_register' ) )
        unless $c->config->{register}{enable_stripe};
    
    $c->redirect_to( 
        $c->ua->get( $c->config->{stripe}->{backend} . '/stripe/get-checkout-link?lookup_key=' . $c->config->{stripe}->{lookup_key} )->result->json->{url}
    );
}

#==
# GET /login | show_login | templates/auth/login.html.ep
#
# If a user is already logged in, redirect them to the dashboard instead
# of showing the login page.
#==
sub login ( $c ) {
    if ( $c->stash->{person} ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
    }
}

#==
# POST /login | do_login
#       email     - The email address of the account to login to.
#       password  - The password for the account to login to.
#
# Try to login to the account owned by the email address with the
# supplied password.
#
# If the account exists and password matches, set the session uid
# to the user's account id.  This will load the correct account to
# $c->stash->{person} on the next page load.
#
# Show the login page with error messages when there has been an error.
#
# Redirect the user to the dashboard on successful login.
#== 
sub do_login ( $c ) {
    my $email    = $c->stash->{form}->{email}    = $c->param('email');
    my $password = $c->stash->{form}->{password} = $c->param('password');

    # Did we get an email address and a password?
    push @{$c->stash->{errors}}, "You must supply an email address to login."
        unless $email;
    
    push @{$c->stash->{errors}}, "You must suply a password to login."
        unless $password;
    
    return $c->redirect_error( 'show_login' )
        if $c->stash->{errors};

    # Can we load a user account?
    my $person = $c->db->resultset('Person')->find( { email => $email } )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";

    return $c->redirect_error( 'show_login' )
        if $c->stash->{errors};

    # Does the user account we loaded have a password that matches the one supplied?
    $person->auth_password->check_password( $password )
        or push @{$c->stash->{errors}}, "Invalid email address or password.";
    
    return $c->redirect_error( 'show_login' )
        if $c->stash->{errors};

    # Everything is good, log the user in and send them to the dashboard.
    $c->session->{uid} = $person->id;
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

#==
# POST /logout | do_logout
#
# Log a user out of their account.
#
# If an admin has logged into a user's account through the admin_become interface,
# then logging out will return the admin to their account instead of logging them
# out completely.
#==
sub do_logout ( $c ) {

    # When an admin has impersonated a user, they'll have their uid
    # stored to oid.  When they logout, they are logging out of the
    # impersonated user's account, back into their own account.
    # If a url is set in the session, the admin is returned to that page.
    if ( $c->session->{oid} ) {
        $c->session->{uid} = delete $c->session->{oid};
        if ( $c->session->{url} ) {
            $c->redirect_to( $c->url_for( delete $c->session->{url} ) );
        } else {
            $c->redirect_to( $c->url_for( 'show_admin' ) );
        }
        return;
    }

    # Delete the session cookie and return them to the homepage.
    undef $c->session->{uid};
    $c->redirect_to( $c->url_for( 'show_homepage' ) );
}

#==
# GET /forgot | show_forgot | templates/auth/forgot.html.ep
#==
sub forgot ( $c ) { }

#==
# POST /forgot | do_forgot
#       email | The email address to reset the password for
#
# When a user requests their password be reset, a token is created
# that can be used to reset the password.
#
# This token is sent to the user via email as a link they can click
# to go to the reset page.
#==
sub do_forgot ( $c ) {
    my $email  = $c->stash->{form}->{email} = $c->param('email');
    
    my $person = $c->db->resultset('Person')->find( { email => $email } )
        or push @{$c->stash->{errors}}, "There is no account with that email address.";

    return $c->redirect_error( 'show_forgot' )
        if $c->stash->{errors};

    # Make a token for password resetting.
    my $token = $c->stash->{token} = $person->create_auth_token( 'forgot' );

    # Send the user an email with the link for resetting.
    $c->send_email( 'forgot_password', {
        send_to => $email, 
        link => 'https://' . $c->config->{domain_for_links} . "/reset/$token"
    });

    # Let the user know the next steps.
    $c->flash( confirmation => 'Please check your email for a password reset link.' );
    $c->redirect_to( $c->url_for( 'show_forgot' ) );
}

sub reset ( $c ) { }

#==
# POST /reset/:token
#       password         | The new password for the user
#       password_confirm | The new password for the user, again
#
# This route is used to reset a password when somebody has a token for
# a password reset on an account.
#==
sub do_reset ( $c ) {
    my $token    = $c->param('token');
    my $password = $c->stash->{form_password}         = $c->param('password');
    my $confirm  = $c->stash->{form_password_confirm} = $c->param('password_confirm');
    
    push @{$c->stash->{errors}}, "Password is required"         unless $password;
    push @{$c->stash->{errors}}, "Confirm Password is required" unless $confirm;

    return $c->redirect_error( 'show_reset', { token => $token } )
        if $c->stash->{errors};

    push @{$c->stash->{errors}}, "Password and confirm password must match"
        unless $confirm eq $password;

    push @{$c->stash->{errors}}, "Password must be at least 8 characters"
        unless length($password) >= 8;
    
    return $c->redirect_error( 'show_reset', { token => $token } )
        if $c->stash->{errors};

    my $lower_time = DateTime->now;
       $lower_time->subtract( minutes => 60 );

    my $dtf = $c->db->storage->datetime_parser;

    my $record = $c->db->auth_tokens->search( {
        token      => $token,
        scope      => 'forgot',
        'me.created_at' => { '>=', $dtf->format_datetime($lower_time) },
    }, { prefetch => 'person'  })->first;

    push @{$c->stash->{errors}}, "This token is not valid."
        unless $record;

    return $c->redirect_error( 'show_reset', { token => $token } )
        if $c->stash->{errors};

    # Change the user's password.
    $record->person->auth_password->update_password( $password );

    # Log the user into the account
    $c->session->{uid} = $record->person->id;

    # Delete this token.
    $record->delete;
    
    # Send them to the dashboard.
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

1;
