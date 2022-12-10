package MJB::Web::Plugin::Email;
use Mojo::Base 'Mojolicious::Plugin', -signatures;
use Email::Sender::Simple qw( sendmail );
use Email::Sender::Transport::SMTP;
use Email::MIME::Kit;

#==
# This plugin supports transactional email.  The email templates are
# stored in mkits/ at the root of the repo.
#
# When this code is under test conditons, email will not be sent.
#==

sub register ( $self, $app, $config ) {

    $app->helper( send_email => sub ($c, $template, $options ) {

        # Do not send email under test conditions.
        if ( $ENV{MJB_TESTMODE} and $ENV{MJB_TESTMODE} == 1 ) {
            # Allow debugging of the emails being send 
            # -- show the template and options:
            #
            # MJB_DEBUG=1 prove -lrv t/01_endpoints/02_auth/10_do_forgot.t
            if ( $ENV{MJB_DEBUG} and $ENV{MJB_DEBUG} == 1 ) {
                require Data::Dumper;
                warn "\n>>> Email Not Sending During Test\n";
                warn "Template: $template\n";
                warn "Options:\n";
                warn Data::Dumper::Dumper $options;
                warn "\n>>> Finished Email\n";
            }
            return undef;
        }


        my $transport =  Email::Sender::Transport::SMTP->new(%{$c->config->{smtp}});
        my $mkit_path = $app->home->child('mkits')->to_string;

        my $kit = Email::MIME::Kit->new({ source => sprintf( "%s/%s.mkit", $mkit_path, $template ) } );

        my $message = $kit->assemble( $options );
        
        sendmail( $message, { transport => $transport } );
    });
}

1;
