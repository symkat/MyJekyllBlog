package MJB::Web::Plugin::Jekyll::Blog::ConfigFile;
use Moo;
use YAML::XS qw( Load Dump );

# File path we are read/write from
has path => (
    is       => 'ro',
    required => 1,
);

has data => (
    is      => 'rw',
    default => sub { return +{} },
);

sub as_text {
    my ( $self ) = @_;

    return Dump($self->data);
}

sub set_from_text {
    my ( $self, $config ) = @_;

    $self->data( Load($config) );

    return $self;
}

sub read {
    my ( $self ) = @_;


    $self->data( { } );
    
    open my $lf, "<", $self->path
        or die "Failed to open " . $self->path . " for reading: $!";

    my $content = do { local $/; <$lf> };

    close $lf;

    $self->data( Load($content) );

    return $self;
}

sub write {
    my ( $self, $file ) = @_;

    $file ||= $self->path;

    open my $sf, ">", $file
        or die "Failed to open $file for writing: $!";

    print $sf Dump($self->data);

    close $sf;
    
    return $self;
}

1;
