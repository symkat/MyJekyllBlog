package MJB::Web::Plugin::Nginx;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use MJB::Web::Plugin::Nginx::DomainConfig;

sub register ( $self, $app, $config ) {

    $app->helper( domain_config => sub ($c, $domain, $ssl_domain) {
        return MJB::Web::Plugin::Nginx::DomainConfig->new(
            domain     => $domain,
            ssl_domain => $ssl_domain,
        )->config;
    });
}

1;
