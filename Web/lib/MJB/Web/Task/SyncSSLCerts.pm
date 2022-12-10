package MJB::Web::Task::SyncSSLCerts;
use Mojo::Base 'MJB::Web::Task', -signatures;
use IPC::Run3;

#==
# This task pushes all of the let's encrypt ssl certs from certbot to
# the webservers.  It can be used after certificates have been renewed
# to ensure they are on the webservers.
#
# It should be in the certbot queue.
#==

sub run ( $job ) {
    $job->note( _job_template => 'sync_ssl_certs' );

    my $servers = $job->app->db->servers;
    my $source  = '/etc/letsencrypt/live';
    my $ssh_opt = 'ssh -o StrictHostKeyChecking=no';

    while ( my $server = $servers->next ) {
        my $dest = "root@" . $server->hostname . ":/etc/letsencrypt";
        $job->system_command( [ qw( sudo rsync -vrLptgoD --delete -e ), $ssh_opt, $source, $dest ]);
    }

    $job->note( is_sync_done => 1 );
    

    $job->finish();
}

1;
