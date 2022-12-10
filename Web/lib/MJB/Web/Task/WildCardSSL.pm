package MJB::Web::Task::WildCardSSL;
use Mojo::Base 'MJB::Web::Task', -signatures;
use IPC::Run3;

#==
# This task creates a wildcard ssl certificate for a hosted domain.
#
# It is currently limited to supporting only linode for dns challenges, but should be
# easy to expand to support other --dns- plugins.
#== 

sub run ( $job, $hosted_domain_id ) {
    $job->note( _job_template => 'wildcard_ssl' );

    my $domain = $job->app->db->hosted_domain( $hosted_domain_id );

    # Get the SSL Certificate
    my $result_fetch = $job->system_command( [
        qw(sudo certbot certonly --dns-linode --dns-linode-credentials /etc/letsencrypt/.secrets/linode.ini -d ), '*.' . $domain->name, qw(--agree-tos --register-unsafely-without-email)
    ]);
    
    $job->note( is_create_done => 1 );
    
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
