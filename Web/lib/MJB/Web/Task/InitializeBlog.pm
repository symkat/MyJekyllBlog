package MJB::Web::Task::InitializeBlog;
use Mojo::Base 'MJB::Web::Task', -signatures;
use Mojo::File qw( curfile tempfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;

#==
# This task makes the initial nginx configuration file, reloads the webservers to have
# the config take effect.  Then it schedules a sync_blog task to get the initial blog up
# on the webservers.
#
# It is expected that the SSL certificates have issued before this task is run, either with
# standing wildcard SSL certs or with the task to complete and sync http challenges.  If the
# SSL certs referenced in the nginx config are missing, that may cause the servers to fail to
# reload.
#==

sub run ( $job, $blog_id ) {
    $job->note( _job_template => 'initialize_blog' );

    my $blog = $job->app->db->blog( $blog_id );
    
    # Create the domain config.
    # When the domain uses a different domain for its ssl cert (i.e. wildcard ssl), we need to supply that.
    my $domain_name    = $blog->domain->name;
    my $domain_ssl     = $blog->domain->ssl ? $blog->domain->ssl : $blog->domain->name;
    my $config_content = $job->app->domain_config( $domain_name, $domain_ssl );
    
    # Put the nginx configuration file and a welcome html file into files for scp'ing to the web servers.
    my ( $config, $welcome ) = ( tempfile, tempfile );
    $config->spurt ( $config_content );
    $welcome->spurt( "Your new blog is being setup... please reload soon." );

    $job->note( is_config_created => 1 );
    
    # Deploy the configuration and initial index.html file to the webservers then reload the webservers for
    # the config to take effect.
    foreach my $host ( $job->app->db->servers->all ) {
        my $server = 'root@' . $host->hostname;
        my $domain = $blog->domain->name;

        $job->system_command( [ 'scp', $config->to_string, $server . ":/etc/nginx/sites-enabled/" . $domain ], { retry_on_ssh_fail => 1 } );
        $job->system_command( [ 'ssh', $server, 'mkdir -p /var/www/' . $domain . '/html' ], { retry_on_ssh_fail => 1 } );
        $job->system_command( [ 'scp', $welcome->to_string, $server . ":/var/www/" . $domain . "/html/index.html" ], { retry_on_ssh_fail => 1 } );
        $job->system_command( [ 'ssh', $server, 'chown -R www-data:www-data /var/www/' . $domain ], { retry_on_ssh_fail => 1 } );
        $job->system_command( [ 'ssh', $server, 'systemctl reload nginx' ], { retry_on_ssh_fail => 1 } );
    }
    
    $job->note( is_config_deployed => 1 );

    $job->finish( );
}

1;
