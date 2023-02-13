#!/usr/bin/env perl
use MJB::Web::Test;

#==
# Initialize Testing Database
#==
MJB::Web::Test::enable_testing_database();

#==
# This test ensures that the export controller will export a blog, and
# checks that the exported file untars and contains the index.markdown file.
#
# 1. Create user and login.
# 2. Make a new blog.
# 3. Submit an export request and get the file
# 4. Ensure that the index.markdown file is in the export.
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
        ok( -f $dir->to_string . '/index.md', 'Index file exists in export.')

    });

#==
# Remove Jekyll blog repos that were created as a part of this test.
#== 
$t->clear_tempdir;

done_testing;
