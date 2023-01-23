package MJB::Web::Plugin::Jekyll::Blog;
use Moo;
use IPC::Run3 qw( run3 );
use Cwd qw( getcwd );
use File::Path qw( make_path remove_tree );
use File::Find;
use Storable qw( dclone );
use Mojo::File;
use MJB::Web::Plugin::Jekyll::Blog::MarkdownFile;
use MJB::Web::Plugin::Jekyll::Blog::ConfigFile;

#======
# This class enables you to programatically access and update Jekyll blogs
# that are backed by a git repository.  Additionally, you can create new
# Jekyll blogs from a repository to use as a template.
# 
#======

#==
# The path to the directory that will be used to hold the git repositories for each blog blogs.
#==
has root => (
    is       => 'ro',
    required => 1,
    trigger  => sub {
        my ( $self, $value ) = @_;
        make_path( $value );
    },
);

#==
# The domain name for this specific blog.
#==
has domain => (
    is       => 'ro',
    required => 1,
);

#==
# The full remote path ( i.e. git@foo.com:mjb/domain.com.git) to the git repository that we will push to.
#==
has repo => (
    is       => 'ro',
    required => 1,
);

#==
# When set to true, push the repo after any action that changes it.
#==
has push_on_change => (
    is      => 'ro',
    default => sub { 1 },
);

#==
# The full local path (i.e. /var/repos/domain.com ) to the git repository that we will execute git commands in.
#==
has repo_path => (
    is => 'lazy',
);

sub _build_repo_path {
    my ( $self ) = @_;

    return $self->root . "/" . $self->domain;
}

#==
# The full git path (i.e. git@foo.com:mjb/default-site.git) of the repository to use as an initial
# template when using the init() method to create a new blog.
#==
has init_from => (
    is       => 'ro',
    required => 1,
);

#==
# The configuration file for the Jekyll blog itself.
#==
has config => (
    is => 'lazy',
);

sub _build_config {
    my ( $self ) = @_;

    return MJB::Web::Plugin::Jekyll::Blog::ConfigFile->new(
        path => $self->repo_path . "/_config.yml",
    )->read;
}

#==
# This method will initialize a new blog.
#
# It will clone the git repo from $self->init_from and set a new remote, then
# push the repository (and expect the git server to create the repo on push).
#
# It returns $self
#==

sub init {
    my ( $self, $init_from ) = @_;

    $init_from ||= $self->init_from;

    # Refuse to overwrite an already-existing site.
    die "Error: Cannot init when the target directory already exists."
        if -d $self->repo_path;

    # Clone the template repo
    $self->system_command( [ qw( git clone  ), $init_from, $self->repo_path ] );
    
    # Kill the git repo
    $self->system_command( [ qw( rm -fr .git ) ], {
        chdir => $self->repo_path,
    });

    # Create new git repo 
    $self->system_command( [ qw( git init ) ], {
        chdir => $self->repo_path,
    });
    
    # Add all the files.
    $self->system_command( [ qw( git add .gitignore * ) ], {
        chdir => $self->repo_path,
    });

    # Add the origin
    $self->system_command( [ qw( git remote add origin ), $self->repo ], {
        chdir => $self->repo_path,
    });

    # Confirm the origin 
    my $return = $self->system_command( [ qw( git remote get-url origin ) ], {
        chdir => $self->repo_path,
    });

    if ( $return->{stdout} ne $self->repo . "\n" ) {
        die "Error: Unable to initialize and set repo.";
    }
    
    # Commit the changes
    $self->system_command( [ qw( git commit -m ), "Created new blog!" ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return $self;
}

#==
# This method will list the media files that are in the blog's /assets/media directory,
# where images, pdfs, etc may be stored.
#
# It returns a list of hashrefs containing
#       path      | The full path to the file
#       filename  | The basename of the file.
#       url       | The http url that the image should exist at
#       markdown  | The markdown code to embedd the asset as an image
#==
sub list_media {
    my ( $self ) = @_;

    $self->_ensure_repository_is_latest;

    my $media = Mojo::File->new( $self->repo_path . "/assets/media" );

    my @return;

    # TODO: Sort by date for the listing on the front end.
    foreach my $file ( $media->list->each ) {
        push @return, {
            path     => $file->to_string,
            filename => $file->basename,
            url      => 'https://' . $self->domain . '/assets/media/' . $file->basename,
            markdown => '![Title for image](https://' . $self->domain . '/assets/media/' . $file->basename . ')',
        };
    }

    return [ @return ];
}

#==
# This method will list posts for the blog that are in the /_posts
# collection..
#
# It returns a list of MJB::Web::Plugin::Jekyll::Blog::MarkdownFile objects.
# 
# Objects are sorted by date with the most most recent first.  The date is based
# only on the date string in the file, and doesn't include the time, so posts on the
# same day may still be out of order.
#
# For speed read() is NOT called on these objects, so the file will
# not be loaded until you call read() on the object.
#==
sub list_posts {
    my ( $self ) = @_;

    $self->_ensure_repository_is_latest;

    my $posts = Mojo::File->new( $self->repo_path . "/_posts" );

    my @files;

    foreach my $file ( $posts->list->each ) {
        my $name = $file->basename;
        my $date = 0;
        if ( $name =~ /^(\d{4})-(\d{2})-(\d{2})-/ ) {
            $date = $1 . $2 . $3;
        }

        push @files, {
            file => MJB::Web::Plugin::Jekyll::Blog::MarkdownFile->new(
                root   => $self->repo_path,
                path   => $file->to_string,
            ),
            date => $date,
        };
    }

    return [
        map { $_->{file} } sort { $b->{date} <=> $a->{date} } @files
    ];
}

#==
# This method will list files and directories for the blog, according to
# the rules below.
#
# Files are html, markdown, and yml files, that are in the top directory
# or a subdirectory that does not begin with . or _  
# 
# Directories are directories that do not begin with . or _
#
#==
sub list_files {
    my ( $self, $dir ) = @_;
    
    return undef if $dir and $dir =~ m|/\.\./|;

    $self->_ensure_repository_is_latest;

    my $posts = Mojo::File->new( $self->repo_path );

    $posts = $posts->child( $dir ) if $dir;

    my @files;

    foreach my $file ( $posts->list({dir => 1})->each ) {
        if ( -d $file ) {
            next if substr($file->basename, 0, 1) eq '_'; # Skip collections.

            push @files, {
                is_dir   => 1,
                filename => $file->basename,
                dirpath  => $file->to_rel( $self->repo_path )->to_string,
                path     => $file->dirname->to_rel( $self->repo_path )->to_string,
            };

            next; # We're done with directories.
        }

        my @allow_exts = ( qw( html md markdown yml yaml ));

        if ( grep { $file->extname eq $_ } @allow_exts ) {
            push @files, {
                is_dir   => 0,
                filename => $file->basename,
                path     => $file->dirname->to_rel( $self->repo_path )->to_string,
            };
        }
    }

    return [
        sort { $b->{is_dir} <=> $a->{is_dir} } @files
    ];
}

sub get_file {
    my ( $self, $file_path ) = @_;

    return undef if $file_path =~ m|/\.\./|;

    my $file = Mojo::File->new( $self->repo_path )->child( $file_path );

    my $segments = $file->dirname->to_rel( $self->repo_path )->to_string;

    my @dir;
    foreach my $segment ( split( m|/|, $segments ) ) {
        my $path = $dir[-1] ? $dir[-1]->{path} : "";

        push @dir, {
            filename => $segment,
            path     => "$path/$segment",
        }
    }

    return +{
        file    => $file,
        dirname => [ @dir ],
    }

}

sub make_dir {
    my ( $self, $dir ) = @_;

    $self->_ensure_repository_is_latest;

    my $root = Mojo::File->new( $self->repo_path );

    my $new_dir = $root->child($dir)->make_path; 
    
    return $self;

}

sub make_file {
    my ( $self, $file ) = @_;

    $self->_ensure_repository_is_latest;

    my $root = Mojo::File->new( $self->repo_path );

    $root->child($file)->touch; 
    
    return $self;

}

#==
# This method removes a markdown file from the git repository for this blog.
# 
# It accepts a Mojo::File object to remove.
# 
# It returns self.
#==
sub remove_markdown_file {
    my ( $self, $file ) = @_;
    
    # Update the origin that is set
    $self->system_command( [ qw( git rm ), $file->path ], {
        chdir => $self->repo_path,
    });
    
    # Commit The Changes
    $self->system_command( [ qw( git commit -m ), 'Removed ' . $file->filename ], {
        chdir => $self->repo_path,
    });

    # Push the changes 
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return $self;
}

#==
# This method lists all of the pages that exist in this blog.
#
# It will search for .md and .markdown files and returns an arrayref
# of MJB::Web::Plugin::Jekyll::Blog::MarkdownFile objects.
#
# For speed read() is NOT called on these objects, so the file will
# not be loaded until you call read() on the object.
#==

sub list_pages {
    my ( $self ) = @_;
    
    $self->_ensure_repository_is_latest;

    my @files;

    find( sub {
        return unless $_ =~ /\.(?:markdown|md)$/;                          # Only markdown files
        return if substr((split m|/|, $File::Find::dir)[-1], 0, 1) eq '_'; # Skip directories that start with _

        push @files, MJB::Web::Plugin::Jekyll::Blog::MarkdownFile->new(
            root => $self->repo_path,
            path => $File::Find::name,
        );
    }, $self->repo_path );

    return [ @files ];
}

#==
# This method will load a post by its filename.
#
# It returns an MJB::Web::Plugin::Jekyll::Blog::MarkdownFile object
# if the file exists.  Otherwise, it returns undef.
#
#==
sub get_post {
    my ( $self, $filename ) = @_;

    return undef
        if $filename =~ m|\.\./|;

    return undef
        unless -f $self->repo_path . "/_posts/" . $filename;

    return MJB::Web::Plugin::Jekyll::Blog::MarkdownFile->new(
        root => $self->repo_path,
        path => $self->repo_path . "/_posts/" . $filename,
    )->read;
}

#==
# This method will create a new post on the blog.
#
# It expects the filename for the collection in YYYY-MM-DD-some-title.markdown format.
# (i.e. 2020-12-25-it-is-christmas.markdown)
#
# It returns an MJB::Web::Plugin::Jekyll::Blog::MarkdownFile object that is expected to be
# populated by the caller.
#
# Once populated, this object should be given to write_post() to commit it.
#
# TODO: get_post and new_post are the very nearly the same, and should be refactored into
#       one function.
#       1. Write a new function load_or_create_post() that will function as get_post, but
#          if the post doesn't exist, it will function as new_post and return an object
#          anyway.
#       2. Run ack in the controllers and update any use of get_post or new_post to use the
#          new function.  Confirm it works at each step of the way.
#       3. Remove get_post and new_post from this file.
#==
sub new_post {
    my ( $self, $filename ) = @_;
    
    return undef
        if $filename =~ m|\.\./|;

    return MJB::Web::Plugin::Jekyll::Blog::MarkdownFile->new(
        root => $self->repo_path,
        path => $self->repo_path . "/_posts/" . $filename,
    );
}

#==
# This method will create a new page.
#
# It expects a filepath in the form of my/file/path/and/name.markdown, and will
# return a MJB::Web::Plugin::Jekyll::Blog::MarkdownFile object.
#
# That object should be given to write_post.
#
# TODO: The difference between this and the post is that this can go off the root
# of the repo, where the posts go off the /_post/.
#
# Think about how this would work with being refactored the same as the new_post bit...
# it could be all three should be one function.
#==
sub new_page {
    my ( $self, $filename ) = @_;
    
    return undef
        if $filename =~ m|\.\./|;

    return MJB::Web::Plugin::Jekyll::Blog::MarkdownFile->new(
        root => $self->repo_path,
        path => $self->repo_path . $filename,
    );
}


#==
# This method writes the jekyll blog configuration file.
#       You can pass an MJB::Web::Plugin::Jekyll::Blog::ConfigFile object to write,
#       otherwise the one in $self is written.
#
# The config file is written, commited, and pushed to the git origin server.
#==
sub write_config {
    my ( $self, $config ) = @_;

    $config ||= $self->config;

    $config->write;
    
    # Add the file to git
    $self->system_command( [ qw( git add ), $config->path ], {
        chdir => $self->repo_path,
    });

    # Commit the file
    $self->system_command( [ qw( git commit -m ), "Updated Site Config" ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;
}

#==
# This method accepts an MJB::Web::Plugin::Jekyll::Blog::MarkdownFile object
# and writes it to the blog, then commits and pushes it to the origin.
#
# It is used by the post and page editing/creating functions.
#==
sub write_post {
    my ( $self, $md_file ) = @_;
    
    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;

    # Write the file
    $md_file->write;
    
    # Add the file to git
    $self->system_command( [ qw( git add ), $md_file->path ], {
        chdir => $self->repo_path,
    });

    # Commit the file
    $self->system_command( [ qw( git commit -m ), "Created " . $md_file->headers->{title} ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;
}

#==
# This method accepts a file path and a comment and will commit the file,
# and push the repo.
#
# This is used to commit media and non-post files.
#==
sub commit_file {
    my ( $self, $file, $comment ) = @_;

    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;

    # Add the file to git
    $self->system_command( [ qw( git add ), $file ], {
        chdir => $self->repo_path,
    });

    # Commit the file
    $self->system_command( [ qw( git commit -m ), $comment ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;

}

#==
# This method accepts a file path and a comment and will remove the file,
# and push the repo.
#
# This is used to delete media and other files.
#==
sub remove_file {
    my ( $self, $file, $comment ) = @_;

    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;

    # Add the file to git
    $self->system_command( [ qw( git rm ), $file ], {
        chdir => $self->repo_path,
    });

    # Commit the file
    $self->system_command( [ qw( git commit -m ), $comment ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;

}

#==
# Given a commit, restore the repo to that state.
#==
sub restore_commit {
    my ( $self, $commit ) = @_;

    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;

    # Restore the commit.
    $self->system_command( [ qw( git restore --source ), $commit, qw( -W -S --theirs :/ ) ], {
        chdir => $self->repo_path,
    });
    
    # Restore the commit.
    $self->system_command( [ qw( git commit -m ), "Restored from $commit" ], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;

}

#==
# This method will import a replacement for the jekyll blog files.
#
# Given a Mojo::File object pointing to a .tgz file, unpack the tgz file
# and replace the blog contents with the contents of the tgz file.
#== 
sub import_from_file {
    my ( $self, $file ) = @_;

    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;
    
    # Remove all of the current files.
    $self->system_command( [ qw( git rm -rf * )], {
        chdir => $self->repo_path,
    });
    
    # Remove all of the current files.
    $self->system_command( [ qw( git commit -m ), "Remove files before restore."], {
        chdir => $self->repo_path,
    });

    # Restore all of the files in the export.
    $self->system_command( [ qw( tar -xzf ), $file->to_string ], {
        chdir => $self->repo_path,
    });
    
    # Remove all of the current files.
    $self->system_command( [ qw( git add * .gitignore )], {
        chdir => $self->repo_path,
    });
    
    # Remove all of the current files.
    $self->system_command( [ qw( git commit -m ), "Restore files via import."], {
        chdir => $self->repo_path,
    });

    # Push the repo to the store server
    $self->system_command( [ qw( git push origin master ) ], {
        chdir => $self->repo_path,
    }) if $self->push_on_change;

    return 1;
}

#==
# This method exports the repo into a .tgz file, and returns a Mojo::File
# object for it.
#==
sub export_to_file {
    my ( $self ) = @_;

    # Check that the repo exists and is latest.
    $self->_ensure_repository_is_latest;

    # Get a temp file.
    my $file = Mojo::File::tempfile;

    # Make a tgz of the blog contents, without the .git directory.
    $self->system_command( [ qw( tar --exclude=.git -czf ), $file->to_string, '.' ], {
        chdir => $self->repo_path,
    });

    # Return the file object
    return $file; 
}

#==
# This method removes the repository directory.
# 
# This directory can be restored by calling 
# $self->_ensure_repository_is_latest.
#==
sub remove_repo {
    my ( $self ) = @_;

    return remove_tree( $self->repo_path );
}


#==
# This method lists the history of the git repo.
#
# It returns an arrayref of hashrefs with the following keys:
#       commit  | The commit hash
#       dateref | The date, expressed relative (i.e. 3 days ago)
#       message | The commit message
#==
sub history {
    my ( $self ) = @_;

    # Check if the repo exists and update the repo if needed
    $self->_ensure_repository_is_latest;

    # Do a git history
    my $result = $self->system_command( [ qw(git log --date=relative), q|--pretty=%H %ad %s| ], {
        chdir => $self->repo_path,
    });

    my @return;


    # Format the results into a data structure
    foreach my $line ( split( /\n/, $result->{stdout} ) ) {
        if ( $line =~ /^([0-9a-f]{40}) (.+ ago) (.+)$/ ) {
            push @return, {
                commit  => $1,
                dateref => $2,
                message => $3,
            };
        }
    }

    # Return the data structure
    return [ @return ];
}

#==
# This method will checkout the repo if it doesn't exist on the filesystem.
#
# It will update the repo with a git pull.
#==
sub _ensure_repository_is_latest {
    my ( $self ) = @_;

    # Check for the repo -- if it doesn't exist, clone it.
    if ( ! -d $self->repo_path ) {
        $self->system_command( [ qw( git clone ), $self->repo, $self->repo_path ] );
        return 1;
    }

    # Run a git pull with fast forward
    $self->system_command( [ qw( git pull --ff-only origin master ) ], {
        chdir => $self->repo_path,
    });

    return 1;
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
