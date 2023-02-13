package MJB::Web::Controller::Dashboard;
use Mojo::Base 'Mojolicious::Controller', -signatures;
use Mojo::File;
use DateTime;
use Encode qw( decode_utf8 encode_utf8 );

#=====
# This file handles the dashboard panel
#
# It is a controller, the template files live in templates/dashboard.
#=====

#==
# GET /dashboard | show_dashboard
#==
sub index ($c) {
    push @{$c->stash->{blogs}},
        $c->stash->{person}->search_related('blogs')->all;
}

#==
# GET /dashboard/blog/:id/ | show_dashboard_blog { id => blog.id }
#
# Show the dashboard for a blog.
#==
sub blog ( $c ) {

}

#==
# GET /dashboard/blog/:id/posts | show_dashboard_blog_posts { id => blog.id }
#
# This route shows a list of blog posts and allows editing or deleting the posts.
#==
sub blog_posts ( $c ) {
    my $blog = $c->stash->{blog};
    $c->stash->{blog_posts} = [  map { $_->read } @{$c->jekyll($blog->domain->name)->list_posts} ];
}

#==
# GET /dashboard/blog/:id/post | show_dashboard_blog_post { id => blog.id }
#
# This route loads the editor for making a new blog post.
#==
sub blog_post ( $c ) {
    # Set the date to now for new posts.
    $c->stash->{form}->{date} = DateTime->now(time_zone => 'America/Los_Angeles')->strftime("%F %H:%M");
}

#==
# POST /dashboard/blog/:id/post | do_dashboard_blog_post { id => blog.id }
#       postTitle   | This is the title of the post, for the YAML header
#       postDate    | This is the date of the post, for the YAML header
#       postContent | This is the content of the post, in markdown for the file contents
#
# This route creates a new blog post.
#
# The slug is created from the date and title.
#==
sub do_blog_post ( $c ) {
    my $blog = $c->stash->{blog};

    my $title   = $c->stash->{form_title}   = $c->param('postTitle');
    my $date    = $c->stash->{form_date}    = $c->param('postDate');
    my $content = $c->stash->{form_content} = $c->param('postContent');

    my $jekyll = $c->jekyll($blog->domain->name);

    # Ensure that the user is allowed to create a post.
    if ( $c->config->{free}{is_limited} ) {

        # If the user has an active subscription, then no check.
        if ( $c->stash->{person}->subscription && $c->stash->{person}->subscription->stripe_customer_id ) {

        } else {
            # If the user is an admin, then no check.
            if ( $c->stash->{person}->is_admin ) {

            } else {
                if ( scalar @{$jekyll->list_posts} >= $c->config->{free}{user_post_limit} ) {
                    $c->flash( error_message => "Your account can create " . $c->config->{free}{user_post_limit} . " posts.  Please upgrade to add another." );
                    $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
                    return;
                }
            }
        }
    }

    my $post   = $c->stash->{post} = $jekyll->new_post( _make_slug( $date, $title ) );

    $post->markdown( $content );
    $post->headers->{title}  = $title;
    $post->headers->{date}   = $date;
    $post->headers->{layout} = 'post';

    $jekyll->write_post( $post );

    $c->sync_blog( $blog );

    $c->flash( confirmation => "Created <strong>$title</strong>!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
}

#==
# GET /dashboard/blog/:id/post/edit | show_dashboard_blog_post_edit { id => blog.id }
#       mdfile | This is the name of the mdfile for the post to edit.
#
# This route loads a post for editing with the simple editor.
#==
sub blog_post_edit ( $c ) {
    my $blog = $c->stash->{blog};

    my $post = $c->stash->{post} = $c->jekyll($blog->domain->name)->get_post( $c->param('mdfile') );

    if ( ! $post ) {
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
    }
}

#==
# POST /dashboard/blog/:id/post/edit | do_dashboard_blog_post_edit { id => blog.id }
#       mdfile      | This is the name of the file for the post to edit
#       postTitle   | This is the title of the post, for the YAML header
#       postDate    | This is the date of the post, for the YAML header
#       postContent | This is the content of the post, in markdown for the file contents
#
# This route is used to edit a post.  It will update the title, date and content of an existing
# markdown file.
#==
sub do_blog_post_edit ( $c ) {
    my $blog = $c->stash->{blog};

    my $title   = $c->stash->{form_title}   = $c->param('postTitle');
    my $date    = $c->stash->{form_date}    = $c->param('postDate');
    my $content = $c->stash->{form_content} = $c->param('postContent');

    my $jekyll = $c->jekyll($blog->domain->name);
    my $post   = $c->stash->{post} = $jekyll->get_post( $c->param('mdfile') );

    $post->markdown( $content );
    $post->headers->{title} = $title;
    $post->headers->{date}  = $date;

    $jekyll->write_post( $post );

    $c->sync_blog( $blog );

    $c->flash( confirmation => "Updated <strong>$title</strong>!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
}

#==
# GET /dashboard/blog/:id/post/alter | show_dashboard_blog_post_alter { id => blog.id }
#       mdfile | This is the name of the mdfile for the post to edit.
#
# This route loads a post for editing with the raw editor that allows editing the post headers.
#==
sub blog_post_alter ( $c ) {
    my $blog = $c->stash->{blog};

    my $post = $c->stash->{post} = $c->jekyll($blog->domain->name)->get_post( $c->param('mdfile') );

    if ( ! $post ) {
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
    }
}

#==
# POST /dashboard/blog/:id/post/alter | do_dashboard_blog_post_alter { id => blog.id }
#       postContent | Text for the markdown section of the file
#       postHeader  | Text for the headers section of the file
#
# This route alters a post, it differs from the post editor in that it expects the full 
# post headers as text.
#==
sub do_blog_post_alter ( $c ) {
    my $blog = $c->stash->{blog};

    my $post = $c->stash->{post} = $c->jekyll($blog->domain->name)->get_post( $c->param('mdfile') );
    
    my $content  = $c->param('postContent');
    my $headers  = $c->param('postHeaders');

    $post->set_headers_from_string( $headers );
    $post->markdown( $content );

    $c->jekyll($blog->domain->name)->write_post( $post );
    
    $c->sync_blog( $blog );

    $c->flash( confirmation => "Updated Post " . $post->headers->{title} . "!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
}

#==
# POST /dashboard/blog/:id/post/remove | show_dashboard_blog_post_remove { id => blog.id }
#       file | This is the name of the file for the post to remove
#
# This route is used to remove a blog post.
#==
sub do_blog_post_remove ( $c ) {
    my $blog = $c->stash->{blog};
    
    my $jekyll = $c->jekyll($blog->domain->name);
    my $post   = $jekyll->get_post( $c->param('file') );
    
    $jekyll->remove_markdown_file( $post );
    
    $c->sync_blog( $blog );

    $c->flash( confirmation => "That post has been removed." );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_posts', { id => $blog->id } ) );
}

#==
# GET /dashboard/blog/:id/jobs | show_dashboard_blog_jobs { id => blog.id }
#
# This route shows the jobs interface with recently run jobs and their logs.
#==
sub blog_jobs ( $c ) {

}

#==
# GET /dashboard/blog/:id/export | show_dashboard_blog_export { id => blog.id }
#
# This route shows the user the export button to let them export their blog.
#==
sub blog_export ( $c ) {

}

#==
# POST /dashboard/blog/:id/export | do_dashboard_blog_export { id => blog.id }
#
# This route will create a blog export for the blog.
#==
sub do_blog_export ( $c ) {
    my $blog = $c->stash->{blog};
    
    my $jekyll = $c->jekyll($blog->domain->name);

    my $file     = $jekyll->export_to_file;
    my $filename = sprintf( 'export-%s-%d.tgz', $blog->domain->name, time );

    $c->res->headers->content_disposition( 'attachment; filename=' . $filename );
    $c->reply->file( $file->to_string );
}

#==
# GET /dashboard/blog/:id/import | show_dashboard_blog_import { id => blog.id }
#
# This route shows the user the import form to let them import their blog
# from a backup / export / custom jekyll blog.
#==
sub blog_import ( $c ) {

}

#==
# POST /dashboard/blog/:id/import | do_dashboard_blog_import { id => blog.id }
#       upload | An HTTP file upload object
#
# This route accepts the upload of a .tgz file to restore the blog from.
#==
sub do_blog_import ( $c ) {
    my $blog = $c->stash->{blog};
    
    my $jekyll = $c->jekyll($blog->domain->name);

    my $upload = $c->req->upload( 'upload' );

    if ( ! $upload->asset->size ) {
        $c->flash( error_message => "You must select a file to upload" );
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_import', { id => $blog->id } ) );
        return;
    }

    my $file = Mojo::File::tempfile;
    $upload->move_to( $file->to_string );

    $jekyll->import_from_file( $file );
    
    $c->flash( confirmation => "Imported from the tgz file!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_import', { id => $blog->id } ) );

}
#==
# GET /dashboard/blog/:id/media | show_dashboard_blog_media { id => blog.id }
#
# This route shows the media / static files hosted for this blog..
#==
sub blog_media ( $c ) {
    my $blog = $c->stash->{blog};
    
    $c->stash->{media_files} = $c->jekyll($blog->domain->name)->list_media;
}

#==
# POST /dashboard/blog/:id/media | do_dashboard_blog_media { id => blog.id }
#       upload | An HTTP file upload object
#
# This route uploads a file and then stores it in the blog as assets/media/filename
#==
sub do_blog_media ( $c ) {
    my $blog = $c->stash->{blog};
    
    my $jekyll = $c->jekyll($blog->domain->name);

    my $upload = $c->req->upload( 'upload' );

    if ( ! $upload->asset->size ) {
        $c->flash( error_message => "You must select a file to upload" );
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_media', { id => $blog->id } ) );
        return;
    }

    # Ensure the upload directory exists.
    Mojo::File->new( $jekyll->repo_path . "/assets/media/" )->make_path;

    # Move the file there
    $upload->move_to( $jekyll->repo_path . "/assets/media/" . $upload->filename );

    $jekyll->commit_file( 
        $jekyll->repo_path . "/assets/media/" . $upload->filename,
        "Add media " . $upload->filename 
    );
    
    $c->sync_blog_media( $blog );

    $c->flash( confirmation => "Uploaded file!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_media', { id => $blog->id } ) );
}

#==
# POST /dashboard/blog/:id/media/*file | do_dashboard_blog_media { id => blog.id, file => name.ext }
#
# This route removes a static file that had been hosted.
#==
sub do_blog_media_remove( $c ) {
    my $blog = $c->stash->{blog};
    my $file = $c->param('file');

    my $jekyll      = $c->jekyll($blog->domain->name);
    my $media_files = Mojo::File->new( $jekyll->repo_path . "/assets/media/" );
    my $media_file  = $media_files->child( $file );

    if ( $media_file->stat ) {
        $jekyll->remove_file( $media_file->to_string, "Removed media file" . $media_file->basename );
    }
    
    $c->sync_blog_media( $blog );
    
    $c->flash( confirmation => "Removed " . $media_file->basename );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_media', { id => $blog->id } ) );

}

#==
# GET /dashboard/blog/:id/history | show_dashboard_blog_history { id => blog.id }
#
# Show the git history for this blog.
#==
sub blog_history ( $c ) {
    my $blog = $c->stash->{blog};
    
    $c->stash->{history} = $c->jekyll($blog->domain->name)->history;
}

#==
# POST /dashboard/blog/:id/history | show_dashboard_blog_history { id => blog.id }
#       commit_hash | The commit hash to undo
#
# This route will undo the commit hash given and then deploy the website.
#
# TODO: This should use restore instead, it would make more sense.
#==
sub do_blog_history ( $c ) {
    my $blog = $c->stash->{blog};
    
    my $commit = $c->param('commit_hash');

    my $jekyll = $c->jekyll($blog->domain->name);

    my $history = $c->stash->{history} = $jekyll->history;

    my ( $old_commit ) = grep { $_->{commit} eq $commit  } @{$history};

    if ( $old_commit ) {
        $jekyll->restore_commit( $commit );

        $c->sync_blog( $blog );

        $c->flash( confirmation => "Restored from $commit!" );
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_history', { id => $blog->id } ) );
    }
}

#==
# GET /dashboard/blog/:id/files | show_dashboard_blog_files { id => blog.id }
#
# This route shows a list of blog files and allows editing or deleting the files.
#==
sub blog_files ( $c ) {
    my $blog = $c->stash->{blog};

    $c->stash->{files} = $c->jekyll($blog->domain->name)->list_files( $c->param('dir'));

    my @dirs = (split( /\//, $c->param('dir') || '' ));
    $c->stash->{dir_nav_dirs}     = [ '/', @dirs ];
    $c->stash->{dir_nav_filename} = '.';
}

#==
# GET /dashboard/blog/:id/file | show_dashboard_blog_file { id => blog.id }
#           ? name = 
#             path =
#
# This route shows a list of blog files and allows editing or deleting the files.
#==
sub blog_file ( $c ) {
    my $blog = $c->stash->{blog};
    my $name = $c->param('name');
    my $dir  = $c->param('dir');

    $name = sprintf( "%s/%s", $dir, $name ) if $dir;

    my $obj = $c->stash->{file} = $c->jekyll($blog->domain->name)->get_file( $name );
    
    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $obj;

    my $file = $obj->{file};

    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $file;
        
    # File exists on disk.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Unable to load file.'] )
        if ! -e $file or ! -f $file;
    
    my @dirs = (split( /\//, $c->param('dir') || '' ));
    $c->stash->{dir_nav_dirs}     = [ '/', @dirs ];

    $c->stash->{file_content}     = decode_utf8($file->slurp); 
}

#==
# POST /dashboard/blog/:id/file | do_dashboard_blog_file { id => blog.id }
#       file_name | The name of the file
#       file_type | The type of file
#       file_path | The directory path to the file
#
# This route creates a new file.
#==
sub do_blog_file ( $c ) {
    my $blog      = $c->stash->{blog};

    my $file_name = $c->param('file_name');
    my $file_type = $c->param('file_type');
    my $file_path = $c->param('file_path');

    my $jekyll = $c->jekyll($blog->domain->name);

    if ( $file_type eq 'directory' ) {
        $jekyll->make_dir( $file_name );

        $c->flash( confirmation => "Created directory!" );
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } ) );
        return;
    } 

    # Filetype is a markdown, html, or yaml file type only.
    if ( ! grep { $file_type eq $_ } ( qw( .md .html .yml )) ) {
        $c->flash( error_message => "Invalid filetype selected.  Please choose from the drop-down menu." );
        $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } ) );
        return;
    }

    $jekyll->make_file( $file_path . '/'. $file_name . $file_type );
    
    $c->sync_blog( $blog );

    $c->flash( confirmation => "Created file $file_name$file_type!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } )->query( dir => $file_path ) );
    return;
}


#==
# POST /dashboard/blog/:id/file/edit | do_dashboard_blog_file_edit { id => blog.id }
#       file_name | The name of the file
#       file_path | The directory path to the file
#       content   | The content for the file.
#
# This route updates the content of a file.
#==
sub do_blog_file_edit ( $c ) {
    my $blog      = $c->stash->{blog};

    my $file_name = $c->param('file_name');
    my $file_path = $c->param('file_path') || '';
    my $content   = $c->param('content');

    my $jekyll = $c->jekyll($blog->domain->name);
    
    my $file = $jekyll->get_file( $file_path . '/'. $file_name )->{file};

    $file->spurt( encode_utf8($content) );

    $jekyll->commit_file( $file->to_string, 'Edit file.' );
    
    $c->sync_blog( $blog );

    $c->flash( confirmation => "Updated file $file_name!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } )->query( dir => $file_path ) );

    return;
}

#==
# GET /dashboard/blog/:id/delete | show_dashboard_blog_file_delete { id => blog.id }
#           ? name = 
#             path =
#
# This route shows a list of blog files and allows editing or deleting the files.
#==
sub blog_file_delete ( $c ) {
    my $blog = $c->stash->{blog};
    my $name = $c->param('name');
    my $dir  = $c->param('dir');

    $name = sprintf( "%s/%s", $dir, $name ) if $dir;

    my $obj = $c->stash->{file} = $c->jekyll($blog->domain->name)->get_file( $name );
    
    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $obj;

    my $file = $obj->{file};

    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $file;
        
    # File exists on disk.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Unable to load file.'] )
        if ! -e $file or ! -f $file;

    $c->stash->{file_nav}         = $obj->{dirname};
    $c->stash->{dir_nav_filename} = $file->basename;
    $c->stash->{file_content}     = $file->slurp; 
    
    my @dirs = (split( /\//, $c->param('dir') || '' ));
    $c->stash->{dir_nav_dirs}     = [ '/', @dirs ];
}

#==
# POST /dashboard/blog/:id/file/delete | do_dashboard_blog_file_delete { id => blog.id }
#       file_name | The name of the file
#       file_path | The directory path to the file
#
# This route deletes file from the jekyll blog.
#==
sub do_blog_file_delete ( $c ) {
    my $blog      = $c->stash->{blog};

    my $file_name = $c->param('file_name');
    my $file_path = $c->param('file_path') || '';

    my $jekyll = $c->jekyll($blog->domain->name);
    
    my $file = $jekyll->get_file( $file_path . '/'. $file_name )->{file};

    $jekyll->remove_file( $file->to_string, "Remove file." );
    
    $c->sync_blog( $blog );
    
    $c->flash( confirmation => "Removed file $file_name!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } )->query( dir => $file_path ) );
}

#==
# GET /dashboard/blog/:id/rename | show_dashboard_blog_file_delete { id => blog.id }
#           ? name = 
#             path =
#
# This route shows a list of blog files and allows editing or deleting the files.
#==
sub blog_file_rename ( $c ) {
    my $blog = $c->stash->{blog};
    my $name = $c->param('name');
    my $dir  = $c->param('dir');

    $name = sprintf( "%s/%s", $dir, $name ) if $dir;

    my $obj = $c->stash->{file} = $c->jekyll($blog->domain->name)->get_file( $name );
    
    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $obj;

    my $file = $obj->{file};

    # Object exists.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Cannot find that file.'] )
        if ! $file;
        
    # File exists on disk.
    return $c->redirect_error( 'show_dashboard_blog_files', { id => $blog->id }, [ 'Unable to load file.'] )
        if ! -e $file or ! -f $file;

    $c->stash->{file_nav}         = $obj->{dirname};
    $c->stash->{dir_nav_filename} = $file->basename;
    $c->stash->{file_content}     = $file->slurp; 
    
    my @dirs = (split( /\//, $c->param('dir') || '' ));
    $c->stash->{dir_nav_dirs}     = [ '/', @dirs ];
}

#==
# POST /dashboard/blog/:id/file/rename | do_dashboard_blog_file_rename { id => blog.id }
#       file_name | The name of the file
#       file_path | The directory path to the file
#       new_name  | 
#       new_path  | 
#
# This route updates the name of a file.
#==
sub do_blog_file_rename ( $c ) {
    my $blog      = $c->stash->{blog};

    my $file_name = $c->param('file_name');
    my $file_path = $c->param('file_path') || '';
    
    my $new_name = $c->param('new_name');
    my $new_path = $c->param('new_path');

    my $jekyll = $c->jekyll($blog->domain->name);

    my $file = $jekyll->get_file( $file_path . '/'. $file_name )->{file};
    my $new  = $jekyll->get_file( $new_path . '/'. $new_name )->{file}; 

    # Put the old content into the new file.
    $new->spurt( $file->slurp );

    # Commit the new file, remove the old file.
    $jekyll->commit_file( $new->to_string, "Copy from $file_name" );
    $jekyll->remove_file( $file->to_string, "Moved to $new_name" );
    
    $c->sync_blog( $blog );

    # Send the user on their way.
    $c->flash( confirmation => "Renamed file $file_name to $new_name!" );
    $c->redirect_to( $c->url_for( 'show_dashboard_blog_files', { id => $blog->id } )->query( dir => $new_path ) );
}

#==
# Helper Function
#
# Create a slug from a date and title.
#
# The date should capture YYYY-MM-DD from the YAML section.
#
# The title will be transformed to all lowercase alphanumeric.
# Extra characters will be removed if they are in the front or end of the title. 
# Extra characters in the middle of the title will be replaced with a single dash(-).
#==
sub _make_slug ( $date, $title ) {
    
    my $slug;

    if ( $date =~ /^(\d{4}-\d{2}-\d{2})/ ) {
        $slug = $1;
    }

    s/[^a-zA-Z0-9_-]+/-/g, s/^[^a-zA-Z0-9]+//, s/[^a-zA-Z0-9]+$// for $title;

    $slug .= lc("-$title.markdown");

    return $slug;

}

1;
