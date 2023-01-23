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
use Cwd qw( getcwd );
use Storable qw( dclone );
use IPC::Run3 qw( run3 );

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
        next if $key eq 'blog';
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

#==
# Run a system command.
#       $self->system_command( 
#           [qw( the command here )],
#           { options => 'here' },
#       );
#
# This method accepts an arrayref with a command, and a hashref with
# options.
#
# The command will be executed.
#
# The following options may be passed:
#       chdir          | Directory to chdir to before executing the command
#       mask           | A hash like { My$ecretP@ssword => '--PASSWORD--' } to censor in
#                        logging STDOUT/STDERR, and logging the command itself.
#       fail_on_stderr | An arrayref like [ 
#                          qr/pattern/       => 'die reason', 
#                          qr/other pattern/ => 'another die reason' 
#                        ] where system_command will emmit a die if the pattern matches on stderr.
#
# A hashref will be returned that contains the following keys:
#  { 
#    stdout => 'standard output content',
#    stderr => 'standard error content',
#    exitno => 1, # the exit status of the command
#  }
#
# If the environment variable MJB_DEBUG is set true, these return values
# will also be printed to STDOUT.
#==
sub system_command {
    my ( $self, $cmd, $settings ) = @_;

    $settings ||= {};

    # Change the directory, if requested.
    if ( $settings->{chdir} ) {
        # Throw an error if that directory doesn't exist.
        die "Error: directory " . $settings->{chdir} . "doesn't exist."
            unless -d $settings->{chdir};

        $settings->{return_chdir} = getcwd();

        # Change to that directory, or die with error.
        chdir $settings->{chdir}
            or die "Failed to chdir to " . $settings->{chdir} . ": $!";
    }

    # Mask values we don't want exposed in the logs.
    my $masked_cmd = dclone($cmd);
    if ( ref $settings->{mask} eq 'HASH' ) {
        foreach my $key ( keys %{$settings->{mask}} ) {
            my $value = $settings->{mask}{$key};
            $masked_cmd = [ map { s/\Q$key\E/$value/g; $_ } @{$masked_cmd} ];
        }
    }

    # Log the lines
    my ( $out, $err );
    my $ret = run3( $cmd, \undef, sub {
        chomp $_;
        # Mask values we don't want exposed in the logs.
        if ( ref $settings->{mask} eq 'HASH' ) {
            foreach my $key ( keys %{$settings->{mask}} ) {
                my $value = $settings->{mask}{$key};
                s/\Q$key\E/$value/g;
            }
        }
        $out .= "$_\n";
    }, sub {
        chomp $_;
        # Mask values we don't want exposed in the logs.
        if ( ref $settings->{mask} eq 'HASH' ) {
            foreach my $key ( keys %{$settings->{mask}} ) {
                my $value = $settings->{mask}{$key};
                s/\Q$key\E/$value/g;
            }
        }
        $err .= "$_\n";
    });

    # Check stderr for errors to fail on.
    if ( $settings->{fail_on_stderr} ) {
        my @tests = @{$settings->{fail_on_stderr}};

        while ( my $regex = shift @tests ) {
            my $reason = shift @tests;

            if ( $err =~ /$regex/ ) {
                die $reason;
            }
        }
    }

    # Return to the directory we started in if we chdir'ed.
    if ( $settings->{return_chdir} ) {
        chdir $settings->{return_chdir}
            or die "Failed to chdir to " . $settings->{return_chdir} . ": $!";
    }

    if ( $ENV{MJB_DEBUG} ) {
        require Data::Dumper;
        print Data::Dumper::Dumper({
            stdout => $out,
            stderr => $err,
            exitno => $ret,
        });
    }

    return {
        stdout => $out,
        stderr => $err,
        exitno => $ret,
    };
}

1;
