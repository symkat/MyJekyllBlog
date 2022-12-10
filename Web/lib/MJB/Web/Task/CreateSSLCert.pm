package MJB::Web::Task::CreateSSLCert;
use Mojo::Base 'MJB::Web::Task', -signatures;
use IPC::Run3;

#==
# This task creates SSL certificates on the certbot server, and then syncs them
# with the webservers.
#
# Certs are created with HTTP challenges.
#== 

sub run ( $job, $blog_id ) {
    $job->note( _job_template => 'create_ssl_cert' );

    my $blog      = $job->app->db->blog( $blog_id );

    # Get the SSL Certificate
    my $result_fetch = $job->system_command( [
        qw(sudo certbot certonly --standalone -d), $blog->domain->name, qw(--agree-tos --register-unsafely-without-email)
    ]);
    
    $job->note( is_create_done => 1 );
    
    # Push the SSL Certs to all hosts
    my $id = $job->app->minion->enqueue( 'sync_ssl_certs', [ ], { 
        queue => 'certbot',
        notes => { '_bid_0' => 1 },
    });
    $job->app->db->admin_jobs->create({ minion_job_id => $id });

    # Don't exit until the sync job is complete.
    while ( $job->app->minion->job( $id )->info->{state} ne 'finished' ) {
        $job->append_log( "Waiting for sync_ssl_certs job with id $id to finish." );
        sleep 5;
    }
    
    $job->note( is_sync_done => 1 );

    $job->finish();
}

1;
