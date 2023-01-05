package MJB::Web::Task::PurgeBlog;
use Mojo::Base 'MJB::Web::Task', -signatures;

#==
# This task removes the blog from the webservers.
# 
# It will remove the configuration file at /etc/nginx/sites-enabled/$domain, and
# the docroot /var/www/.
#
# It does not attempt to purge any SSL configurations.
#==

sub run ( $job, $domain ) {
    
    foreach my $host ( $job->app->db->servers->all ) {
        my $server = 'root@' . $host->hostname;
        
        $job->system_command( [ 'ssh', $server, "rm /etc/nginx/sites-enabled/" . $domain ], 
            { retry_on_ssh_fail => 1 } 
        );
        $job->system_command( [ 'ssh', $server, 'rm -rf /var/www/' . $domain],
            { retry_on_ssh_fail => 1 } 
        );
        $job->system_command( [ 'ssh', $server, 'systemctl reload nginx' ], 
            { retry_on_ssh_fail => 1 }
        );
    }

    $job->finish( );
}

1;
