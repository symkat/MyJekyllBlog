package MJB::Web::Plugin::Jekyll::Blog::MarkdownFile;
use Moo;
use YAML::XS qw( Load Dump );
use Mojo::File;

# File path we are read/write from
has path => (
    is       => 'ro',
    required => 1,
);

# root / domain from parent class.
has root => (
    is       => 'ro',
    required => 1,
);

has rel_path => (
    is => 'lazy',
);

sub _build_rel_path {
    my ( $self ) = @_;

    return substr($self->path, length($self->root));
}

has filename => (
    is => 'lazy',
);

sub _build_filename {
    my ( $self ) = @_;

    return (split( /\//, $self->path ))[-1];
}

has headers => (
    is      => 'rw',
    default => sub { return +{} },
);

has markdown => (
    is => 'rw',
);

sub headers_as_string {
    my ( $self ) = @_;

    return Dump($self->headers);
}

sub set_headers_from_string {
    my ( $self, $string ) = @_;

    $self->headers( Load( $string ) );

    return $self;
}

sub read {
    my ( $self ) = @_;

    # Ensure any content we alread have is discarded before reading.
    $self->markdown( undef );
    $self->headers( { } );

    open my $lf, "<", $self->path
        or die "Failed to open " . $self->path . " for reading: $!";

    my $sep_count = 0;
    my ( $yaml, $markdown ) = ( undef, undef );

    while ( defined( my $line = <$lf> ) ) {

        if ( $sep_count < 2 ) {
            $yaml .= $line;
        } else {
            $markdown .= $line;
        }

        $sep_count++ if $line =~ /^---$/;
    }
    
    $self->headers( Load($yaml) );
    $self->markdown( $markdown );

    return $self;
}

sub write {
    my ( $self, $file ) = @_;

    $file ||= $self->path;

    # Make directory if it doesn't exist.
    Mojo::File->new( $file )->dirname->make_path;

    open my $sf, ">", $file
        or die "Failed to open $file for writing: $!";

    print $sf Dump($self->headers);
    print $sf "---\n";
    print $sf $self->markdown;

    close $sf;
    
    return $self;
}

1;
