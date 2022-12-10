package MJB::Web::Task::UpdateSSLCerts;
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
    $job->note( _job_template => 'update_ssl_certs' );

    # Renew the SSL Certificates
    $job->system_command( [ 'sudo', 'certbot', 'renew' ] );
    $job->note( is_renew_done => 1 );

    # Push the SSL Certs to all hosts
    my $id = $job->app->minion->enqueue( 'sync_ssl_certs', [ ], { 
        queue => 'certbot',
        notes => { '_bid_0' => 1 },
    });
    $job->app->db->admin_jobs->create({ minion_job_id => $id });

    $job->note( is_sync_done => 1 );
    

    $job->finish();
}

1;
