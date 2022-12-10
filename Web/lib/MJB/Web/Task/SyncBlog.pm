package MJB::Web::Task::SyncBlog;
use Mojo::Base 'MJB::Web::Task', -signatures;
use Mojo::File qw( curfile );
use File::Copy::Recursive qw( dircopy );
use IPC::Run3;

sub run ( $job, $blog_id ) {
    $job->note( _job_template => 'sync_blog' );

    my $build_dir = $job->checkout_repo( $blog_id );
    my $blog      = $job->app->db->blog( $blog_id );

    $job->note( is_clone_complete => 1 );

    # Show the user the commit we're on.
    $job->system_command( [ 'git', '-C', $build_dir->child('src')->to_string, 'log', '-1' ] );

    $build_dir->child('build')->make_path;

    $job->system_command( [qw( podman run -ti --rm -v .:/srv/jekyll -e JEKYLL_ROOTLESS=1 docker.io/jekyll/jekyll jekyll build ) ], {
        chdir => $build_dir->child('src')->to_string,
    });

    $job->process_webroot(
        $blog,
        $build_dir->child('src')->child('_site')->to_string,
        $build_dir->child('build')->to_string
    );

    $job->note( is_build_complete => 1 );


    my $servers = $job->app->db->servers;

    my $domain  = $blog->domain->name;
    my $source  = $build_dir->child('build')->child('html')->to_string . "/";
    my $ssh_opt = 'ssh -o StrictHostKeyChecking=no';

    while ( my $server = $servers->next ) {
        my $dest = "root@" . $server->hostname . ":/var/www/$domain/html/";
        $job->system_command( [ qw( rsync -vrLptgoD --delete -e ), $ssh_opt, $source, $dest ], { retry_on_ssh_fail => 1 });
    }

    $job->note( is_deploy_complete => 1 );
    $job->finish( );
}

1;
