#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the import controller will import a blog.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Submit an export request and get the file
# 4. Ensure that the index.md file is in the export.
# 5. Create a new file in this export, and then repackage it
# 6. Submit the modified file to be imported, confirm it works.
# 7. Export the blog and confirm the new file exists.
#==

my $t = Test::Mojo::MJB->new('MJB::Web');

my $blog_id = $t->create_user
    ->post_ok( '/blog/domain', form => {
        domain        => 'blog.example.com',
        calling_route => 'show_blog_domain_owned',
    })
    ->get_ok( '/dashboard' )
    ->stash->{blogs}->[0]->id;

$t->post_ok( "/dashboard/blog/$blog_id/export" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;

        # Sore the export itself in a temp file.
        my $file = Mojo::File::tempfile( SUFFIX => '.tgz' );
        $file->spurt($t->tx->res->body);

        # Create a temp directory, and untar the export.
        my $dir = Mojo::File::tempdir;
        $t->system_command( [ qw( tar -xzf ), $file->to_string ], {
            chdir => $dir->to_string,
        } );

        # Confirm the index.markdown file exists.
        ok( -f $dir->to_string . '/index.md', 'Index file exists in export.');
        
        # Confirm the new.markdown file doesn't exist.
        ok( ! -f $dir->to_string . '/new.markdown', "New file doesn't exists in first export.");

        # Add a new.markdown file.
        $dir->child('new.markdown')->spurt('Hello World');
        
        # Confirm the new.markdown file does exist - the import worked!
        ok( -f $dir->to_string . '/new.markdown', "New file exists - the export worked.");

        # Sore the export itself in a temp file.
        $t->system_command( [ qw( tar -czf export.tgz . )], {
            chdir => $dir->to_string,
        });

        # Upload the file.
        $t->post_ok( "/dashboard/blog/$blog_id/import",  form => {
            upload => { file => $dir->to_string . '/export.tgz' },
        })->status_is( 302 )
        ->header_is( location => "/dashboard/blog/$blog_id/import");
    });

$t->post_ok( "/dashboard/blog/$blog_id/export" )
    ->status_is( 200 )
    ->code_block( sub {
        my $self = shift;

        # Sore the export itself in a temp file.
        my $file = Mojo::File::tempfile( SUFFIX => '.tgz' );
        $file->spurt($t->tx->res->body);

        # Create a temp directory, and untar the export.
        my $dir = Mojo::File::tempdir;
        $t->system_command( [ qw( tar -xzf ), $file->to_string ], {
            chdir => $dir->to_string,
        } );

        # Confirm the index.markdown file exists.
        ok( -f $dir->to_string . '/index.md', 'Index file exists in export.');
        
        # Confirm the new.markdown file does exist - the import worked!
        ok( -f $dir->to_string . '/new.markdown', "New file exists - the export worked.");

    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
