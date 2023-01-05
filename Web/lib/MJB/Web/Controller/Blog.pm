package MJB::Web::Controller::Blog;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;

#=====
# This file handles the initial creation of a blog.
#
# It is a controller, the template files live in templates/blog.
#=====

#==
# GET /blog | show_blog
#
# Show the template selection for creating a new blog.
#==
sub index ( $c ) {

}

#==
# GET /blog/domain/hosted | show_blog_domain_hosted
#
# The initial entrypoint for blog creation.
#==
sub domain_hosted ( $c ) {

}

#==
# GET /blog/domain/owned | show_blog_domain_owned
#
# The initial entrypoint for blog creation on a domain that the user controls
# DNS for.
#==
sub domain_owned ( $c ) {
    my $record = $c->db->hosted_domains->first;
    $c->stash->{dns_record} = 'external.' . ( defined $record ? $record->name : 'please-add-a-hosted-domain.invalid' );
}

#==
# POST /blog/domain | do_blog_domain
#       domain           | Host a FQDN.  This will use http ssl challenge and
#                        | expect the user to have already configured DNS.
#       hosted_subdomain | Host on a subdomain that the system knows about.
#       hosted_domain_id | The id of a hosted_domain that the user wants to use
#       calling_route    | The route that called this (i.e. show_domain_hosted)
#
#       domain OR ( hosted_subdomain AND hosted_domain_id ) is required, in addition
#       to calling_route.
# 
# This route will create a blog on a given domain.  When domain is given, use that
# as a FQDN with http ssl challenge.
#
# When hosted_subdomain is given, prepend it to the name of the domain identified by 
# hosted_domain_id, and use whatever ssl challenge method the hosted_domain is set to
# use.
#
# When an error happens, the calling_route will be returned to:
#
# show_blog_domain_hosted
# show_blog_domain_owned
#==
sub do_domain ( $c ) {
    my $domain           = $c->stash->{form}->{domain}           = lc($c->param('domain') || "");
    my $hosted_subdomain = $c->stash->{form}->{hosted_subdomain} = lc($c->param('hosted_subdomain') || "");
    my $hosted_domain_id = $c->stash->{form}->{hosted_domain_id} = $c->param('hosted_domain_id');
    my $calling_route    = $c->stash->{form}->{calling_route}    = $c->param('calling_route');

    if ( $calling_route eq 'show_blog_domain_owned' ) {
        $c->stash->{fqdn} = $domain;

        # Domain name defined?
        push @{$c->stash->{errors}}, "Please enter a value for the domain name."
            unless $domain;

        # Already exists?
        push @{$c->stash->{errors}}, "That domain name is already being used."
            unless $c->db->domains( { name => $domain  } )->count == 0;

    } elsif ( $calling_route eq 'show_blog_domain_hosted' ) {
        $c->stash->{hosted_domain} = $c->db->hosted_domain( $hosted_domain_id );
        $c->stash->{form}->{hdid}  = $c->stash->{hosted_domain}->id;
        $c->stash->{fqdn}          = $hosted_subdomain . '.' . $c->stash->{hosted_domain}->name;
        $c->stash->{ssl_domain}    = $c->stash->{hosted_domain}->letsencrypt_challenge ne 'http' ? $c->stash->{hosted_domain}->name : '';

        # Valid hosted_domain selected.
        push @{$c->stash->{errors}}, "Please select a domain from the drop down menu."
            unless $c->stash->{hosted_domain};

        # Sub domain was answered.
        push @{$c->stash->{errors}}, "Please enter a value for the subdomain."
            unless $hosted_subdomain;
        
        # Subdomain is valid.
        push @{$c->stash->{errors}}, "Subdomains must start with a letter, and may use letters, numbers, dashes and hyphens."
            unless $hosted_subdomain =~ /^[a-z]+[a-z0-9-_]*$/;

        # Already exists?
        push @{$c->stash->{errors}}, "That domain name is already being used."
            unless $c->db->domains( { name => $c->stash->{fqdn} } )->count == 0;

    } else {
        # Shouldn't have gotten here.
        push @{$c->stash->{errors}}, "If you continue to experience problems, please contact support.";
        $calling_route = 'show_blog_domain_hosted';
    }

    # Ensure that the user is allowed to create a blog.
    if ( $c->config->{free}{is_limited} ) {

        # If the user has an active subscription, then no check.
        if ( $c->stash->{person}->subscription && $c->stash->{person}->subscription->stripe_customer_id ) {

        } else {
            # If the user is an admin, then no check.
            if ( $c->stash->{person}->is_admin ) {

            } else {
                if ( $c->stash->{person}->blogs->count >= $c->config->{free}{user_blog_limit} ) {
                    push @{$c->stash->{errors}}, "Your account can create " . $c->config->{free}{user_blog_limit} . " blogs.  Please upgrade to add another.";
                }
            }
        }
    }

    
    # Bail on any errors.
    return $c->redirect_error( $calling_route )
        if $c->stash->{errors};

    # Set scalars to values from stash, and initialize Jekyll blog.
    my $hosted_domain = $c->stash->{hosted_domain};
    my $fqdn          = $c->stash->{fqdn};
    my $ssl_domain    = $c->stash->{ssl_domain};
    
    # Figure out the template we are using and then initalize the blog with it.
    my $theme     = $c->param('theme') || 'minima';
    my $init_repo = $c->config->{theme_gitrepo_prefix} . 'jekyll-' . $theme . '.git';

    my $jekyll    = $c->jekyll($fqdn)->init($init_repo);

    my $blog = try {
        $c->db->storage->schema->txn_do( sub {
            # Make the domain name record.
            my $domain_record = $c->stash->{person}->create_related('domains', {
                name => $fqdn,
                ( $ssl_domain ? ( ssl => $ssl_domain ) : () ),
            });

            # Make the website record
            my $blog = $c->stash->{person}->create_related('blogs', {
                domain_id => $domain_record->id,
            });

            $blog->create_related( 'repoes', {
                url => $jekyll->repo,
            });

            return $blog;
        });
    } catch {
        push @{$c->stash->{errors}}, "Blog could not be created: $_";
    };
    
    # Bail on any errors.
    return $c->redirect_error( $calling_route )
        if $c->stash->{errors};
    

    # Now I need to configure the web servers to handle this domain.
    #
    # If there is an $ssl_domain, then the SSL cert is already handled,
    # likely a wildcard.
    #
    # Otherwise, make one and then configure nginx afterwards.
    my $ssl_job_id = 0;
    if ( ! $ssl_domain ) {
        # Do not run this job in test mode.
        if ( ! $c->is_testmode ) {
            $ssl_job_id = $c->minion->enqueue( 'create_ssl_cert', [ $blog->id ], {
                notes    => { '_bid_' . $blog->id => 1 },
                priority => $blog->build_priority,
                queue    => 'certbot',
            });
            $blog->create_related( 'jobs', { minion_job_id => $ssl_job_id } );
        } 
    }

    # This code creates the nginx configuration and everything.  Don't run it in
    # test mode.
    if ( ! $c->is_testmode ) {
        my $build_job_id = $c->minion->enqueue( 'initialize_blog', [ $blog->id ], {
            notes    => { '_bid_' . $blog->id => 1 },
            priority => $blog->build_priority,

            # We we're creating an SSL cert, wait until that is done.
            $ssl_job_id ? ( parents => [ $ssl_job_id ] ) : (),
        });
        $blog->create_related( 'jobs', { minion_job_id => $build_job_id } );
    }
    
    $c->redirect_to( $c->url_for( 'show_blog_settings', { id => $blog->id } ) );
}

#==
# GET /blog/:id/settings | show_blog_settings
#
# This page gives the user the chance to set the title, description, email, etc.
#==
sub settings ( $c ) {
    my $blog = $c->stash->{blog} = $c->db->blog( $c->param('id') );

    # Make sure that a blog can be loaded.
    if ( ! $blog ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    # Make sure the current user owns the blog that has been loaded.
    if ( $blog->person->id ne $c->stash->{person}->id ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }
}

#==
# POST /blog/:id/settings | do_blog_settings
#       configTitle | The title for the blog
#       configDesc  | The description for the blog
#       configEmail | An email address for the blog's author
# 
# This route handles the initial configuration of the blog, and schedules
# the minion job to initialize it.
#==
sub do_settings ( $c ) {
    my $blog = $c->stash->{blog} = $c->db->blog( $c->param('id') );

    # Make sure that a blog can be loaded.
    if ( ! $blog ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    # Make sure the current user owns the blog that has been loaded.
    if ( $blog->person->id ne $c->stash->{person}->id ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    my $jekyll = $c->jekyll($blog->domain->name);
    
    my $title   = $c->stash->{form_title}  = $c->param( 'configTitle' );
    my $desc    = $c->stash->{form_desc}   = $c->param( 'configDesc'  );
    my $email   = $c->stash->{form_email}  = $c->param( 'configEmail' );

    $jekyll->config->data->{title}       = $title;
    $jekyll->config->data->{description} = $desc;
    $jekyll->config->data->{email}       = $email;
    $jekyll->config->data->{url}         = 'https://' . $blog->domain->name ;

    $jekyll->write_config;

    $c->sync_blog( $blog );
    
    $c->flash( confirmation => "Welcome to the dashboard for your new blog!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog', { id => $blog->id } ) );
}

#==
# GET /blog/:id/remove | show_blog_remove
#
# This gives the user the button to delete their blog and a warning about
# doing so.
#==
sub remove ( $c ) {
    my $blog = $c->stash->{blog} = $c->db->blog( $c->param('id') );

    # Make sure that a blog can be loaded.
    if ( ! $blog ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    # Make sure the current user owns the blog that has been loaded.
    if ( $blog->person->id ne $c->stash->{person}->id ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }
}

#==
# POST /blog/:id/remove | do_blog_remove
#
# This route deletes a blog by doing the following:
# 
# - Clear the database entries
# - Clear the blog from Gitea
# - Clear the blog repo from the panel server
# - Purge the blog from the webservers
# - Purge the site configuration from the webservers
# - Purge the html root from the webservers
#==
sub do_remove ( $c ) {
    my $blog   = $c->stash->{blog} = $c->db->blog( $c->param('id') );
    my $domain = $blog->domain->name;

    # Make sure that a blog can be loaded.
    if ( ! $blog ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    # Make sure the current user owns the blog that has been loaded.
    if ( $blog->person->id ne $c->stash->{person}->id ) {
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    }

    # Remove the blog records.
    try {
        $c->db->storage->schema->txn_do( sub {
            my $domain_record = $blog->domain;

            # Delete the repo record.
            $blog->repo->delete;

            # Delete any existing job records.
            foreach my $job ( $blog->jobs->all ) {
                $job->delete;
            }

            # Delete the blog record itself.
            $blog->delete;

            # Delete the domain record.
            $domain_record->delete;

            return 1;
        });
    } catch {
        push @{$c->stash->{errors}}, "Blog could not be removed: $_";
    };
    
    # Bail on any DB errors.
    return $c->redirect_error( 'show_blog_remove', { id => $blog->id } )
        if $c->stash->{errors};
    
    # Remove the site webroot and config from the webservers. 
    $c->minion->enqueue( 'purge_blog', [ $domain ] ) 
        unless $c->is_testmode; # Do not run jobs in test mode.
    
    # Remove the repo from this server.
    $c->jekyll($domain)->remove_repo;

    # Notify the system about the delete, we'll need to manually do the following:
    # - Remove the git repo from the Gitea server so mjb/<domain> can be used
    $c->db->system_notes->create({
        source => 'Blog Deletion',
        content => "The blog for $domain has been deleted.  Please remove the repo from gitea."
    });
    
    $c->flash( confirmation => "The blog for $domain has been removed." );
    $c->redirect_to( $c->url_for( 'show_dashboard' ) );
}

1;
