package MJB::Web;
use Mojo::Base 'Mojolicious', -signatures;
use MJB::DB;

sub startup ($self) {
    my $config = $self->plugin('NotYAMLConfig', { file => -e 'mjb.yml'
        ? 'mjb.yml'
        : '/etc/mjb.yml'
    });
    
    # Make an attribute that is true when running in test mode.
    $self->helper( is_testmode => sub {
        return 1 if exists $ENV{MJB_TESTMODE} && $ENV{MJB_TESTMODE} == 1;
        return 0;
    });

    # Some quick configs....
    $self->config->{register}->{require_invite} = 1;

    # Configure the application
    $self->secrets($config->{secrets});

    # Set the cookie expires to 30 days.
    $self->sessions->default_expiration(2592000);

    # Load our custom commands.
    push @{$self->commands->namespaces}, 'MJB::Web::Command';
    
    # Add MJB::Web::Plugin to plugin search path.
    push @{$self->plugins->namespaces}, 'MJB::Web::Plugin';

    # Load the MJB::Web::Plugin::Nginx plugin for $c->domain_config
    $self->plugin('Nginx');
    
    # Load the MJB::Web::Plugin::Email plugin for $c->send_email
    $self->plugin('Email');
    
    # Load the MJB::Web::Plugin::Jekyll plugin for $c->jekyll
    $self->plugin('Jekyll');


    # Create $self->db as an MJB::DB connection.
    $self->helper( db => sub ($c) {
        return state $db = $c->is_testmode
            ? MJB::DB->connect( $ENV{MJB_DSN}, '', '' )
            : MJB::DB->connect($self->config->{database}->{mjb});
    });

    $self->helper( sync_blog => sub ( $c, $blog ) {
        return if $c->is_testmode; # Do not run jobs in test mode.

        my $build_job_id = $c->minion->enqueue( 'sync_blog', [ $blog->id ], {
            notes    => { '_bid_' . $blog->id => 1 },
            priority => $blog->build_priority,
        });
        $blog->create_related( 'jobs', { minion_job_id => $build_job_id } );
    });

    $self->helper( sync_blog_media => sub ( $c, $blog ) {
        return if $c->is_testmode; # Do not run jobs in test mode.

        my $build_job_id = $c->minion->enqueue( 'sync_blog_media', [ $blog->id ], {
            notes    => { '_bid_' . $blog->id => 1 },
            priority => $blog->build_priority,
        });
        $blog->create_related( 'jobs', { minion_job_id => $build_job_id } );
    });

    # Helper to redirect on errors, support setting the form and errors in a flash
    # if they exist in the stash.
    $self->helper( redirect_error => sub ( $c, $redirect_to, $redirect_args = {}, $errors = [] ) {
        push @{$c->stash->{errors}}, @{$errors}    if $errors;
        $c->flash( form   => $c->stash->{form}   ) if $c->stash->{form};
        $c->flash( errors => $c->stash->{errors} ) if $c->stash->{errors};

        $c->redirect_to( $c->url_for( $redirect_to, $redirect_args ) );
    });

    # Helper to redirect on success, support setting a message and redirecting to a named route.
    $self->helper( redirect_success => sub ( $c, $redirect_to, $success_message ) {
        $c->flash( confirmation => $success_message );
        $c->redirect_to( $c->url_for( $redirect_to ) );
    });

    # Minion plugin & tasks
    $self->plugin( Minion => { Pg => $self->config->{database}->{minion} }      );

    # Blog deployment related jobs.
    $self->minion->add_task( initialize_blog => 'MJB::Web::Task::InitializeBlog' );
    $self->minion->add_task( purge_blog      => 'MJB::Web::Task::PurgeBlog'      );
    $self->minion->add_task( sync_blog       => 'MJB::Web::Task::SyncBlog'       );
    $self->minion->add_task( sync_blog_media => 'MJB::Web::Task::SyncBlogMedia'  );

    # SSL cert related jobs.
    $self->minion->add_task( mk_wildcard_ssl  => 'MJB::Web::Task::WildCardSSL'    );
    $self->minion->add_task( create_ssl_cert  => 'MJB::Web::Task::CreateSSLCert'  );
    $self->minion->add_task( sync_ssl_certs   => 'MJB::Web::Task::SyncSSLCerts'   );
    $self->minion->add_task( update_ssl_certs => 'MJB::Web::Task::UpdateSSLCerts' );

    # Standard router.
    my $r = $self->routes->under( '/' => sub ($c)  {

        # If the user has a uid session cookie, then load their user account.
        if ( $c->session('uid') ) {
            my $person = $c->db->resultset('Person')->find( $c->session('uid') );
            if ( $person && $person->is_enabled ) {
                $c->stash->{person} = $person;
            }
        }

        # If the user filled a form out and there was an error, we may have
        # the content of the form in a flash, let's load that into the stash.
        $c->stash->{form} = $c->flash( 'form' );

        return 1;
    });

    # Create a router chain that ensures the request is from an authenticated user.
    my $auth = $r->under( '/' => sub ($c) {

        # Logged in user exists.
        if ( $c->stash->{person} ) {
            # Continue
            return 1;
        }

        # No user account for this seession.
        $c->redirect_to( $c->url_for( 'show_login' ) );
        return undef;
    });

    # Create a router chain for the dashboard blog display that verifies access to
    # the blog and loads it.
    my $blog = $auth->under( '/dashboard/blog/:id' => sub ( $c )  {
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

        return 1;
    });

    # Create a router chain that ensures the request is from an admin user.
    my $admin = $auth->under( '/' => sub ($c) {

        # Logged in user exists.
        if ( $c->stash->{person}->is_admin ) {
            return 1;
        }

        # No user account for this seession.
        $c->redirect_to( $c->url_for( 'show_dashboard' ) );
        return undef;
    });

    # Minion Admin Panel
    $self->plugin( 'Minion::Admin' => { 
        route => $admin->under('/minion' => sub ($c) { return 1; } ),
    });

    # General Informational Pages
    $r->get   ( '/'            )->to( 'Root#index'       )->name('show_homepage'    );
    $r->get   ( '/about'       )->to( 'Root#about'       )->name('show_about'       );
    $r->get   ( '/contact'     )->to( 'Root#contact'     )->name('show_contact'     );
    $r->get   ( '/pricing'     )->to( 'Root#pricing'     )->name('show_pricing'     );
    $r->get   ( '/open-source' )->to( 'Root#open_source' )->name('show_open_source' );

    # User registration, login, and logout.
    $r->get   ( '/register'             )->to( 'Auth#register'             )->name('show_register'             );
    $r->get   ( '/register/open'        )->to( 'Auth#register_open'        )->name('show_register_open'        );
    $r->post  ( '/register/open'        )->to( 'Auth#do_register_open'     )->name('do_register_open'          );
    $r->get   ( '/register/invite'      )->to( 'Auth#register_invite'      )->name('show_register_invite'      );
    $r->post  ( '/register/invite'      )->to( 'Auth#do_register_invite'   )->name('do_register_invite'        );
    $r->get   ( '/register/stripe'      )->to( 'Auth#register_stripe'      )->name('show_register_stripe'      );
    $r->post  ( '/register/stripe'      )->to( 'Auth#do_register_stripe'   )->name('do_register_stripe'        );
    $r->get   ( '/register/stripe/pay'  )->to( 'Auth#register_stripe_pay'  )->name('show_register_stripe_pay'  );
    $r->get   ( '/login'                )->to( 'Auth#login'                )->name('show_login'                );
    $r->post  ( '/login'                )->to( 'Auth#do_login'             )->name('do_login'                  );
    $auth->get( '/logout'               )->to( 'Auth#do_logout'            )->name('do_logout'                 );

    # User Forgot Password Workflow.
    $r->get ( '/forgot'       )->to('Auth#forgot'    )->name('show_forgot' );
    $r->post( '/forgot'       )->to('Auth#do_forgot' )->name('do_forgot'   );
    $r->get ( '/reset/:token' )->to('Auth#reset'     )->name('show_reset'  );
    $r->post( '/reset/:token' )->to('Auth#do_reset'  )->name('do_reset'    );

    # User setting changes when logged in
    $auth->get ( '/profile'      )->to('UserSettings#profile'                )->name('show_profile'           );
    $auth->post( '/profile'      )->to('UserSettings#do_profile'             )->name('do_profile'             );
    $auth->get ( '/password'     )->to('UserSettings#change_password'        )->name('show_change_password'   );
    $auth->post( '/password'     )->to('UserSettings#do_change_password'     )->name('do_change_password'     );
    $auth->get ( '/subscription' )->to('UserSettings#subscription'           )->name('show_subscription'      );
    $auth->post( '/subscription' )->to('UserSettings#do_subscription'        )->name('do_subscription'        );
    $auth->post( '/manage'       )->to('UserSettings#do_subscription_manage' )->name('do_subscription_manage' );

    # Dashboard / Blog Management
    $auth->get ( '/dashboard'    )->to('Dashboard#index'                )->name('show_dashboard'                  );

    # This Dashboard $blog route starts at /dashboard/blog/:id
    $blog->get ( '/'             )->to('Dashboard#blog'                 )->name('show_dashboard_blog'             );
    $blog->get ( '/posts'        )->to('Dashboard#blog_posts'           )->name('show_dashboard_blog_posts'       );
    $blog->get ( '/post'         )->to('Dashboard#blog_post'            )->name('show_dashboard_blog_post'        );
    $blog->post( '/post'         )->to('Dashboard#do_blog_post'         )->name('do_dashboard_blog_post'          );
    $blog->get ( '/post/edit'    )->to('Dashboard#blog_post_edit'       )->name('show_dashboard_blog_post_edit'   );
    $blog->post( '/post/edit'    )->to('Dashboard#do_blog_post_edit'    )->name('do_dashboard_blog_post_edit'     );
    $blog->get ( '/post/alter'   )->to('Dashboard#blog_post_alter'      )->name('show_dashboard_blog_post_alter'  );
    $blog->post( '/post/alter'   )->to('Dashboard#do_blog_post_alter'   )->name('do_dashboard_blog_post_alter'    );
    $blog->post( '/post/remove'  )->to('Dashboard#do_blog_post_remove'  )->name('do_dashboard_blog_post_remove'   );
    $blog->get ( '/settings'     )->to('Dashboard#blog_settings'        )->name('show_dashboard_blog_settings'    );
    $blog->post( '/settings'     )->to('Dashboard#do_blog_settings'     )->name('do_dashboard_blog_settings'      );
    $blog->get ( '/config'       )->to('Dashboard#blog_config'          )->name('show_dashboard_blog_config'      );
    $blog->post( '/config'       )->to('Dashboard#do_blog_config'       )->name('do_dashboard_blog_config'        );
    $blog->get ( '/jobs'         )->to('Dashboard#blog_jobs'            )->name('show_dashboard_blog_jobs'        );
    $blog->get ( '/export'       )->to('Dashboard#blog_export'          )->name('show_dashboard_blog_export'      );
    $blog->post( '/export'       )->to('Dashboard#do_blog_export'       )->name('do_dashboard_blog_export'        );
    $blog->get ( '/import'       )->to('Dashboard#blog_import'          )->name('show_dashboard_blog_import'      );
    $blog->post( '/import'       )->to('Dashboard#do_blog_import'       )->name('do_dashboard_blog_import'        );
    $blog->get ( '/media'        )->to('Dashboard#blog_media'           )->name('show_dashboard_blog_media'       );
    $blog->post( '/media'        )->to('Dashboard#do_blog_media'        )->name('do_dashboard_blog_media'         );
    $blog->post( '/media/remove' )->to('Dashboard#do_blog_media_remove' )->name('do_dashboard_blog_media_remove'  );
    $blog->get ( '/history'      )->to('Dashboard#blog_history'         )->name('show_dashboard_blog_history'     );
    $blog->post( '/history'      )->to('Dashboard#do_blog_history'      )->name('do_dashboard_blog_history'       );
    $blog->get ( '/files'        )->to('Dashboard#blog_files'           )->name('show_dashboard_blog_files'       );
    $blog->get ( '/file'         )->to('Dashboard#blog_file'            )->name('show_dashboard_blog_file'        );
    $blog->post( '/file'         )->to('Dashboard#do_blog_file'         )->name('do_dashboard_blog_file'          );
    $blog->post( '/file/edit'    )->to('Dashboard#do_blog_file_edit'    )->name('do_dashboard_blog_file_edit'     );
    $blog->get ( '/file/delete'  )->to('Dashboard#blog_file_delete'     )->name('show_dashboard_blog_file_delete' );
    $blog->post( '/file/delete'  )->to('Dashboard#do_blog_file_delete'  )->name('do_dashboard_blog_file_delete'   );
    $blog->get ( '/file/rename'  )->to('Dashboard#blog_file_rename'     )->name('show_dashboard_blog_file_rename' );
    $blog->post( '/file/rename'  )->to('Dashboard#do_blog_file_rename'  )->name('do_dashboard_blog_file_rename'   );

    # Blog Creation
    $auth->get ( '/blog'               )->to('Blog#index'               )->name('show_blog'                );
    $auth->get ( '/blog/domain/hosted' )->to('Blog#domain_hosted'       )->name('show_blog_domain_hosted'  );
    $auth->get ( '/blog/domain/owned'  )->to('Blog#domain_owned'        )->name('show_blog_domain_owned'   );
    $auth->post( '/blog/domain'        )->to('Blog#do_domain'           )->name('do_blog_domain'           );
    $auth->get ( '/blog/initialize'    )->to('Blog#do_initialize'       )->name('do_blog_initialize'       );
    $auth->get ( '/blog/:id/settings'  )->to('Blog#settings'            )->name('show_blog_settings'       );
    $auth->post( '/blog/:id/settings'  )->to('Blog#do_settings'         )->name('do_blog_settings'         );
    $auth->get ( '/blog/:id/remove'    )->to('Blog#remove'              )->name('show_blog_remove'         );
    $auth->post( '/blog/:id/remove'    )->to('Blog#do_remove'           )->name('do_blog_remove'           );

    # Admin Dashboard
    $admin->get ( '/admin'                 )->to('Admin#index'                )->name('show_admin'                 );
    $admin->post( '/admin'                 )->to('Admin#do_admin_become'      )->name('do_admin_become'            );
    $admin->get ( '/admin/people'          )->to('Admin#people'               )->name('show_admin_people'          );
    $admin->get ( '/admin/person/:id'      )->to('Admin#person'               )->name('show_admin_person'          );
    $admin->post( '/admin/person/:id/note' )->to('Admin#do_person_note'       )->name('do_admin_person_note'       );
    $admin->get ( '/admin/blogs'           )->to('Admin#blogs'                )->name('show_admin_blogs'           );
    $admin->get ( '/admin/domains'         )->to('Admin#domains'              )->name('show_admin_domains'         );
    $admin->post( '/admin/domain'          )->to('Admin#do_domain'            )->name('do_admin_domain'            );
    $admin->post( '/admin/domain/remove'   )->to('Admin#do_domain_remove'     )->name('do_admin_domain_remove'     );
    $admin->get ( '/admin/servers'         )->to('Admin#servers'              )->name('show_admin_servers'         );
    $admin->post( '/admin/server'          )->to('Admin#do_server'            )->name('do_admin_server'            );
    $admin->post( '/admin/server/remove'   )->to('Admin#do_server_remove'     )->name('do_admin_server_remove'     );
    $admin->get ( '/admin/invites'         )->to('Admin#invites'              )->name('show_admin_invites'         );
    $admin->post( '/admin/invite'          )->to('Admin#do_invite'            )->name('do_admin_invite'            );
    $admin->post( '/admin/invite/remove'   )->to('Admin#do_invite_remove'     )->name('do_admin_invite_remove'     );
    $admin->get ( '/admin/alerts'          )->to('Admin#alerts'               )->name('show_admin_alerts'          );
    $admin->post( '/admin/alert/unread'    )->to('Admin#do_alert_unread'      )->name('do_admin_alert_unread'      );
    $admin->post( '/admin/alert/read'      )->to('Admin#do_alert_read'        )->name('do_admin_alert_read'        );
    $admin->post( '/admin/alert/remove'    )->to('Admin#do_alert_remove'      )->name('do_admin_alert_remove'      );
    $admin->get ( '/admin/jobs'            )->to('Admin#jobs'                 )->name('show_admin_jobs'            );
    $admin->post( '/admin/update_ssl'      )->to('Admin#do_update_ssl'        )->name('do_admin_update_ssl'        );
    $admin->post( '/admin/sync_ssl'        )->to('Admin#do_sync_ssl'          )->name('do_admin_sync_ssl'          );

}

1;

