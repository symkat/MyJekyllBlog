package MJB::Web::Controller::Root;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Try::Tiny;
use DateTime;

#=====
# This file handles the more-or-less static pages.
#
# It is a controller, the template files live in templates/root.
#=====

#==
# GET / | show_homepage
#==
sub index   ( $c ) { }

#==
# GET /about | show_about
#==
sub about   ( $c ) { }

#==
# GET /contact | show_contact
#==
sub contact ( $c ) { }

1;
