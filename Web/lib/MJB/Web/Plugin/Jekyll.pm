package MJB::Web::Plugin::Jekyll;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use MJB::Web::Plugin::Jekyll::Blog;

sub register ( $self, $app, $config ) {
    my %opts = ();
    if ( $app->is_testmode ) {
        $opts{push_on_change} = 0;
        $opts{root}           = $ENV{MJB_TESTMODE_TEMPDIR},
    }

    $app->helper( jekyll => sub ($c, $domain) {
        return MJB::Web::Plugin::Jekyll::Blog->new(
            root      => '/home/manager/mjb/Web/repos',
            domain    => $domain,
            init_from => $c->config->{jekyll_init_repo},
            repo      => $c->config->{store_repo_base} . "$domain.git",
            %opts,
        );
    });
}


1;
