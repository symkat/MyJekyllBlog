package Test::Mojo::MJB;
# This package subclasses Test::Mojo and sets up some
# functionality.
#
# _stash_
# The $t object will now have a stash method that returns
# the stash.
# 
# _code_block_
# The $t object will now have a code_block method that
# accepts a code block, runs it, and returns $t.
#
# This combination of stash and code_block enable a
# pattern like the following:
#  
# $t->post_ok( '/login', { user => $user, pass => $pass})
#   ->code_block( sub { 
#     my $t = shift;
#     is($t->stash->{person}->user, $user, "User saved in stash."); 
#   })->status_is( 200 );
# 
# _dump_stash_
# The $t object now has a dump_stash method that prints the
# stash to STDERR.  By default this will supress mojo-specific
# stash elements, pass a true value to dump the full stash.
# 
# $t->get_ok('/')
#   ->dump_stash(1)
#   ->status_is(200);
#
use warnings;
use strict;
use parent 'Test::Mojo';
use Data::Dumper;
use Test::Deep;
use Test::More;
use File::Path qw( remove_tree );

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->app->hook( after_dispatch => sub {
        my ( $c ) = @_;
        $self->stash( $c->stash );
    });

    return $self;
}

sub stash {
    my $self = shift;
    $self->{stash} = shift if @_;
    return $self->{stash};
}

sub code_block  {
    my ( $t, $code ) = @_;

    $code->($t);

    return $t;
}

sub dump_content {
    my ( $t ) = @_;

    warn $t->tx->res->body;

    return $t;
}

sub dump_stash {
    my ( $t, $show_all ) = @_;

    if ( $show_all ) {
        warn Dumper $t->stash;
        return $t;
    }

    my $ds;

    foreach my $key ( keys %{$t->stash}) {
        next if $key eq 'controller';
        next if $key eq 'action';
        next if $key eq 'cb';
        next if $key eq 'template';
        next if $key eq 'person';
        next if $key =~ m|^mojo\.|;

        $ds->{$key} = $t->stash->{$key};
    }
    
    warn Dumper $ds;

    return $t;
}

sub dump_stash_keys {
    my ( $t ) = @_;

    warn Dumper grep {
        $_ ne 'controller' &&
        $_ ne 'action'     &&
        $_ ne 'cb'         &&
        $_ ne 'template'   &&
        $_ ne 'person'     &&
        $_ !~ m|^mojo\.|;

    } keys %{$t->stash};

    return $t;
}

sub stash_has {
    my ( $t, $expect, $desc ) = @_;

    cmp_deeply( $t->stash, superhashof($expect), $desc);

    return $t;
}

#==
# Create a user account and login to it.
# 
# settings accepts is_admin, when true promote the user
# to an admin account.
#==
sub create_user {
    my ( $t, %settings  ) = @_;

    # Enable open registration.
    my $old = $t->app->config->{register}{enable_open};
    $t->app->config->{register}{enable_open} = 1;

    # Create an 8-character random string to use as user/name/pass.
    my $user = join( '', map({ ('a'..'z','A'..'Z')[int rand 52] } ( 0 .. 8)) );
    $t->post_ok( '/register/open', form => { 
        name             => $user,
        email            => "$user\@myjekyllblog.net",
        password         => $user,
        password_confirm => $user,
    })
    ->get_ok( '/')
    ->code_block( sub {
        my $self = shift;
        is($self->stash->{person}->name, $user, "Created test user $user");
        if ( exists $settings{is_admin} and $settings{is_admin} == 1 ) {
            $self->stash->{person}->is_admin( 1 );
            $self->stash->{person}->update;
            is( $self->stash->{person}->is_admin, 1, "Promoted $user to admin" );
        }
    });
    
    # Reset open registration to old value.
    $t->app->config->{register}{enable_open} = $old;

    return $t;
}

sub create_tag {
    my ( $t, $tag, $is_adult ) = @_;

    $t->post_ok( '/tags/suggest', form => {
        tag => $tag,
        ($is_adult ? ( is_adult => 1 ) : ( ) ),
    });

    return $t;
}

# Storage stack for a run, convenience for stashing stuff.
sub _ss {
    my ( $t, $data_stack ) = @_;
    $t->{data_stack} = $data_stack;
    return $t;
}

sub _sg {
    return shift->{data_stack};
}

sub clear_tempdir {
    my ( $t ) = @_;

    remove_tree( $ENV{MJB_TESTMODE_TEMPDIR} )
        if -d $ENV{MJB_TESTMODE_TEMPDIR};
}

1;
