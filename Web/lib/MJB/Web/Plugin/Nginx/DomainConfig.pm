package MJB::Web::Plugin::Nginx::DomainConfig;
use Moo;
use Mojo::File;

has domain => (
    is => 'ro',
);

has ssl_domain => (
    is => 'ro',
);

has template => (
    is => 'ro',
    default => sub {return <<'        EOF;'
        server {
            server_name {{ domain }};
            root /var/www/{{ domain }}/html;
            index index.html;

            error_log  /var/log/nginx/{{ domain }}.error.log warn;
            access_log /var/log/nginx/{{ domain }}.access.log combined;

            listen 443 ssl;
            ssl_certificate /etc/letsencrypt/live/{{ ssl_domain }}/fullchain.pem;
            ssl_certificate_key /etc/letsencrypt/live/{{ ssl_domain }}/privkey.pem;

            ssl_session_cache shared:le_nginx_SSL:10m;
            ssl_session_timeout 1440m;
            ssl_session_tickets off;

            ssl_protocols TLSv1.2 TLSv1.3;
            ssl_prefer_server_ciphers off;

            ssl_ciphers "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384";

            ssl_dhparam /etc/nginx/ssl-dhparams.pem;

        }

        server {
            if ($host = {{ domain }}) {
                return 301 https://$host$request_uri;
            }

            listen 80;
            server_name {{ domain }}
            return 404;
        }
        EOF;
    }
);

has config => (
    is => 'lazy',
);

sub _build_config {
    my ( $self ) = @_;
    
    my $config = $self->template;

    # Fill in variables in the template.
    my ( $domain, $ssl_domain ) = ( $self->domain, $self->ssl_domain );

    s/\{\{ domain \}\}/$domain/g, 
    s/\{\{ ssl_domain \}\}/$ssl_domain/g
        for $config;

    # Trim the excess whitespace
    $config =~ s/^ {8}//gm;
    

    return $config;
}

1;
