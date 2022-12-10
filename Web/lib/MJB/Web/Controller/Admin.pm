package MJB::Web::Controller::Admin;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;

#=====
# This file handles the admin panel
#
# It is a controller, the template files live in templates/admin.
#=====

#==
# GET /admin | show_admin
#
# Redirect to the people listing page.
#==
sub index ( $c ) {
    $c->redirect_to( 'show_admin_people' );
}

#==
# POST /admin | do_admin_become
#       uid | A user id, that the admin would like to become
#       bid | A blog id, that the admin will go to the manage page for
#       url | A URL to return to when the admin logs out of the user account
#
# An admin may inpersonate any other user for technical support purposes,
# this code is called to become another user.  Sign out to become your origional
# user again.
# 
# When given a uid, become that user and go to the user's dashboard.
#
# When given a uid and a bid that the user owns, become that user 
# and go to the blog's dashboard.
#==
sub do_admin_become ( $c ) {
    my ( $uid, $bid, $url ) = ( $c->param('uid'), $c->param('bid'), $c->param('url') );

    $c->session->{oid} = $c->stash->{person}->id;
    $c->session->{uid} = $uid;
    $c->session->{url} = $url if $url;

    # If we have a blog id, then redirect to that blog's dashboard.  
    # Otherwise, the normal dashboard..
    if ( $bid ) {
        $c->redirect_to( $c->url_for( 'show_dashboard_blog', { id => $bid } ) );
    } else {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
    }
}

#==
# GET /admin/people | show_admin_people
#
# This route shows people, users, who exist on this system.
#==
sub people ( $c ) {
    my $people = $c->stash->{people} = [ $c->db->people->all ];
}

#==
# GET /admin/person/:id | show_admin_person, { id => ? }
#
# This route shows a given person, their blogs, and notes about them.
#==
sub person ( $c ) {
    my $profile = $c->stash->{profile} = $c->db->person( $c->param('id') );
    my $notes   = $c->stash->{notes}   = [ $profile->person_note_people->all ];
}

#==
# POST /admin/person/:id/note | do_admin_person_note { id => person.id }
#       content | The content of the message about this user. 
#
# This route makes a note about a person on their profile page.
#==
sub do_person_note ( $c ) {
    my $profile = $c->db->person( $c->param('id') );
    my $content = $c->param('content');

    $profile->create_related( 'person_note_people', {
        source_id => $c->stash->{person}->id,
        content   => $content,
    });
    
    $c->flash( confirmation => "Added note to this account." );
    $c->redirect_to( $c->url_for( 'show_admin_person', { id => $profile->id } ) );
}

#==
# GET /admin/blogs | show_admin_blogs
#
# This route lists blogs that are hosted on this system.
#==
sub blogs ( $c ) {
    my $blogs = $c->stash->{blogs} = [ $c->db->blogs->all ];

}

#==
# GET /admin/invites | show_admin_invites
#
# This route shows the invites that currently exist and can be used.
#==
sub invites ( $c ) {
    my $invites = $c->stash->{invites} = [ $c->db->invites->all ];
    
}

#==
# POST /admin/invite | do_admin_invite
#       code         | The invite code, this is case-sensitive.
#       is_multi_use | When true, the code may be used more than once.
#
# This route adds an invite code.
#==
sub do_invite ( $c ) {
    my $code         = $c->param('code');
    my $is_multi_use = $c->param('is_multi_use' );

    try {
        $c->db->storage->schema->txn_do( sub {
            $c->db->invites->create({  
                code => $code, 
                ( $is_multi_use ? ( is_one_time_use => 0 ) : ( is_one_time_use => 1 ) ),
            });
        });
    } catch {
        push @{$c->stash->{errors}}, "Invite code could not be created: $_";
    };
    
    return $c->redirect_error( 'show_admin_invites' )
        if $c->stash->{errors};

    return $c->redirect_success( 'show_admin_invites', "Added $code to invites." );
}

#==
# POST /admin/invite/remove | do_admin_invite_remove
#       iid | The id of the invite code to delete
#
# This route deletes an invite code.
#==
sub do_invite_remove ( $c ) {
    my $invite = $c->db->invite($c->param('iid'));

    return $c->redirect_error( 'show_admin_invites', {}, [ 'The invite does not exist' ] )
        unless $invite;

    my $code = $invite->code;
    $invite->delete;

    return $c->redirect_success( 'show_admin_invites', "Removed $code from invite pool." );
}

#==
# GET /admin/servers | show_admin_servers
#
# This route shows servers that blogs are hosted on, and deployed to.
#==
sub servers ( $c ) {
    my $servers = $c->stash->{servers} = [ $c->db->servers->all ];
}

#==
# POST /admin/server | do_admin_server
#       server_fqdn | The domain name to use for the server, builder and certbot
#                     servers should have ssh access to these servers.
#
# This route adds a server to the pool for deployment.  These servers are used by
# the certbot and builder servers to deploy ssl certs and blogs to.
#==
sub do_server ( $c ) {
    my $fqdn = $c->param('server_fqdn');

    my $server = try {
        $c->db->storage->schema->txn_do( sub {
            $c->db->servers->create({  hostname => $fqdn });
        });
    } catch {
        push @{$c->stash->{errors}}, "Server could not be created: $_";
    };
    
    return $c->redirect_error( 'show_admin_servers' )
        if $c->stash->{errors};

    return $c->redirect_success( 'show_admin_servers', "Added $fqdn to server pool." );
}

#==
# POST /admin/server/remove | do_admin_server_remove
#       sid | The id of the server to remove
#
# This route removes a server from the rotation used for deploying blogs/ssl certs.
#==
sub do_server_remove ( $c ) {
    my $server = $c->db->server($c->param('sid'));

    return $c->redirect_error( 'show_admin_servers', {}, [ 'The server does not exist' ] )
        unless $server;

    my $hostname = $server->hostname;
    $server->delete;

    return $c->redirect_success( 'show_admin_servers', "Removed $hostname to server pool." );
}

#==
# GET /admin/domains | show_admin_domains
#
# This route shows domains that users can host their blogs under.
#==
sub domains ( $c ) {
    $c->stash->{domains} = [ $c->db->hosted_domains->all ];
}

#==
# POST /admin/domain | do_admin_domain
#       domain_fqdn   | The fully qualified domain name we will use for hosting (i.e. foobar.net)
#       ssl_challenge | The challenge type -- dns-linode or http to use for validating domains
#
# This route will add a domain to use for hosting.  For example, if one adds foobar.net, then
# users will be able to host blogs like myblog.foobar.net.
#
# http challenges will use the certbot server and /.well-known/ forwarding for creation/updating w/ --standalone
# dns-linode challenges will use the --dns-linode plugin and credentials expected to be done with ansible.
#==
sub do_domain ( $c ) {
    my $fqdn = $c->param('domain_fqdn');
    my $ssl  = $c->param('ssl_challenge');

    my $domain = try {
        $c->db->storage->schema->txn_do( sub {
            $c->db->hosted_domains->create({  name => $fqdn, letsencrypt_challenge => $ssl });
        });
    } catch {
        push @{$c->stash->{errors}}, "Domain could not be created: $_";
    };

    return $c->redirect_error( 'show_admin_domains' )
        if $c->stash->{errors};

    if ( $ssl eq 'dns-linode' ) {
        my $id = $c->minion->enqueue( 'mk_wildcard_ssl', [ $domain->id ], { 
            queue => 'certbot',
            notes => { '_bid_0' => 1 },
        });
        $c->db->admin_jobs->create({ minion_job_id => $id });
    }

    return $c->redirect_success( 'show_admin_domains', "Added $fqdn to domain pool." );
}

#==
# POST /admin/domain/remove | do_admin_domain_remove
#       did | The ID for the domain to remove.
#
# This route will remove a hosted domain by its ID.
#==
sub do_domain_remove ( $c ) {
    my $domain = $c->db->hosted_domain($c->param('did'));

    return $c->redirect_error( 'show_admin_domains', {}, [ "That domain doesn't seem to exist." ] )
        unless $domain;

    my $hostname = $domain->name;
    $domain->delete;

    return $c->redirect_success( 'show_admin_domains', "Removed $hostname from domain pool." );
}

#==
# POST /admin/update_ssl | do_admin_update_ssl
#
# This route will schedule a job for update_ssl SSL certs on
# the certbot server and then sync them with the webserver.
# certbot server to the webservers.
#==
sub do_update_ssl ( $c ) {
    my $id = $c->minion->enqueue( 'update_ssl_certs', [ ], { 
        queue => 'certbot',
        notes => { '_bid_0' => 1 },
    });
    $c->db->admin_jobs->create({ minion_job_id => $id });
    
    return $c->redirect_success( 'show_admin_jobs', 'Scheduled job to update SSL certs.' );
}

#==
# POST /admin/sync_ssl | do_admin_sync_ssl
#
# This route will schedule a job for syncing SSL certs from the
# certbot server to the webservers.
#==
sub do_sync_ssl ( $c ) {
    my $id = $c->minion->enqueue( 'sync_ssl_certs', [ ], { 
        queue => 'certbot',
        notes => { '_bid_0' => 1 },
    });
    $c->db->admin_jobs->create({ minion_job_id => $id });
    
    return $c->redirect_success( 'show_admin_jobs', 'Scheduled job to sync SSL certs.' );
}

#==
# GET /admin/alerts | show_admin_alerts
#
# This route shows alerts that have been send through the system_notes table
#==
sub alerts ( $c ) {
    push @{$c->stash->{alerts}},
        $c->db->system_notes( { }, { order_by => { -desc => 'created_at' } } )->all;
}

#==
# POST /admin/alert/read | do_admin_alert_read
#       nid | The ID for the system_note
#
# This route will mark a system_note as read when given the note id.
#==
sub do_alert_read ( $c ) {
    my $note = $c->db->system_note( $c->param('nid') );

    return $c->redirect_error( 'show_admin_alerts', {}, [ "That note doesn't seem to exist." ] )
        unless $note;

    $note->is_read( 1 );
    $note->update;

    return $c->redirect_success( 'show_admin_alerts', 'Note marked as read.' );

}

#==
# POST /admin/alert/unread | do_admin_alert_unread
#       nid | The ID for the system_note
#
# This route will mark a system_note as unread when given the note id.
#==
sub do_alert_unread ( $c ) {
    my $note = $c->db->system_note( $c->param('nid') );

    return $c->redirect_error( 'show_admin_alerts', {}, [ "That note doesn't seem to exist." ] )
        unless $note;

    $note->is_read( 0 );
    $note->update;

    return $c->redirect_success( 'show_admin_alerts', 'Note marked as unread.' );
}

#==
# POST /admin/alert/remove | do_admin_alert_remove
#       nid | The ID for the system_note
#
# This route will delete a system_note when given the note id.
#==
sub do_alert_remove ( $c ) {
    my $note = $c->db->system_note( $c->param('nid') );

    return $c->redirect_error( 'show_admin_alerts', {}, [ "That note doesn't seem to exist." ] )
        unless $note;

    $note->delete;

    return $c->redirect_success( 'show_admin_alerts', 'Note removed.' );
}

1;
