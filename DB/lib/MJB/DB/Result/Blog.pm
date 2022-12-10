use utf8;
package MJB::DB::Result::Blog;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::Blog

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 COMPONENTS LOADED

=over 4

=item * L<DBIx::Class::InflateColumn::DateTime>

=item * L<DBIx::Class::InflateColumn::Serializer>

=back

=cut

__PACKAGE__->load_components("InflateColumn::DateTime", "InflateColumn::Serializer");

=head1 TABLE: C<blog>

=cut

__PACKAGE__->table("blog");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'blog_id_seq'

=head2 person_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 domain_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 max_static_file_count

  data_type: 'integer'
  default_value: 100
  is_nullable: 0

=head2 max_static_file_size

  data_type: 'integer'
  default_value: 5
  is_nullable: 0

=head2 max_static_webroot_size

  data_type: 'integer'
  default_value: 50
  is_nullable: 0

=head2 minutes_wait_after_build

  data_type: 'integer'
  default_value: 10
  is_nullable: 0

=head2 builds_per_hour

  data_type: 'integer'
  default_value: 3
  is_nullable: 0

=head2 builds_per_day

  data_type: 'integer'
  default_value: 12
  is_nullable: 0

=head2 build_priority

  data_type: 'integer'
  default_value: 1
  is_nullable: 0

=head2 is_enabled

  data_type: 'boolean'
  default_value: true
  is_nullable: 0

=head2 created_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  {
    data_type         => "integer",
    is_auto_increment => 1,
    is_nullable       => 0,
    sequence          => "blog_id_seq",
  },
  "person_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "domain_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "max_static_file_count",
  { data_type => "integer", default_value => 100, is_nullable => 0 },
  "max_static_file_size",
  { data_type => "integer", default_value => 5, is_nullable => 0 },
  "max_static_webroot_size",
  { data_type => "integer", default_value => 50, is_nullable => 0 },
  "minutes_wait_after_build",
  { data_type => "integer", default_value => 10, is_nullable => 0 },
  "builds_per_hour",
  { data_type => "integer", default_value => 3, is_nullable => 0 },
  "builds_per_day",
  { data_type => "integer", default_value => 12, is_nullable => 0 },
  "build_priority",
  { data_type => "integer", default_value => 1, is_nullable => 0 },
  "is_enabled",
  { data_type => "boolean", default_value => \"true", is_nullable => 0 },
  "created_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
);

=head1 PRIMARY KEY

=over 4

=item * L</id>

=back

=cut

__PACKAGE__->set_primary_key("id");

=head1 RELATIONS

=head2 domain

Type: belongs_to

Related object: L<MJB::DB::Result::Domain>

=cut

__PACKAGE__->belongs_to(
  "domain",
  "MJB::DB::Result::Domain",
  { id => "domain_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 jobs

Type: has_many

Related object: L<MJB::DB::Result::Job>

=cut

__PACKAGE__->has_many(
  "jobs",
  "MJB::DB::Result::Job",
  { "foreign.blog_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);

=head2 person

Type: belongs_to

Related object: L<MJB::DB::Result::Person>

=cut

__PACKAGE__->belongs_to(
  "person",
  "MJB::DB::Result::Person",
  { id => "person_id" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);

=head2 repoes

Type: has_many

Related object: L<MJB::DB::Result::Repo>

=cut

__PACKAGE__->has_many(
  "repoes",
  "MJB::DB::Result::Repo",
  { "foreign.blog_id" => "self.id" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-11 23:06:57
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:VQHf6EwwxUUAGeyMVk6KAw

use DateTime;

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id                       => $self->id,
        person_id                => $self->person_id,
        domain_id                => $self->domain_id,
        max_static_file_count    => $self->max_static_file_count,
        max_static_file_size     => $self->max_static_file_size,
        max_static_webroot_size  => $self->max_static_webroot_size,
        minutes_wait_after_build => $self->minutes_wait_after_build,
        builds_per_hour          => $self->builds_per_hour,
        builds_per_day           => $self->builds_per_day,
        build_priority           => $self->build_priority,
        is_enabled               => $self->is_enabled,
        created_at               => $self->created_at->strftime( '%F %T' ),
    };
}

sub repo {
    my ( $self ) = @_;

    return $self->search_related( 'repoes' )->first;

}

sub get_builds {
    my ( $self ) = @_;

    return [ map { +{
        id                 => $_->id,
        job_id             => $_->job_id,
        date               => $_->created_at->strftime( "%F %T %Z" ),
    } } $self->search_related( 'builds', { }, { order_by => { -DESC => 'created_at' } } ) ];
}

sub build_count {
    my ( $self, @time ) = @_;

    if ( ! @time ) {
        return $self->search_related( 'builds', { }, { } )->count;
    }

    return $self->search_related( 'builds',
        {
            created_at => {
                '>=',
                $self->result_source->schema->storage->datetime_parser->format_datetime(
                    DateTime->now->subtract( @time )
                )
            }
        },
        {
        },
    )->count;
}

sub minutes_since_last_build {
    my ( $self ) = @_;

    my ( $build ) = $self->search_related( 'builds', { }, { order_by => { -DESC => 'created_at' }, limit => 1 } )->all;

    return undef unless $build;

    return DateTime->now->subtract_datetime( $build->created_at )->in_units( 'minutes' );

}

sub get_build_allowance {
    my ( $self ) = @_;

    # Create a data structure with the build restrictions.
    #
    # If there is no build yet, set minutes_since_last_build to one more than
    # minutes_wait_after_build so this test passes to make the first build.
    my $data = {
        can_build => undef,
        total_builds => $self->build_count,

        wait_minutes => {
            required  => $self->minutes_wait_after_build,
            current   => defined $self->minutes_since_last_build ? $self->minutes_since_last_build : ( $self->minutes_wait_after_build + 1 ),
            can_build => undef,
        },

        builds_over_hour => {
            allowed   => $self->builds_per_hour,
            used      => $self->build_count( hours => 1 ),
            can_build => undef,
        },

        builds_over_day => {
            allowed   => $self->builds_per_day,
            used      => $self->build_count( hours => 24 ),
            can_build => undef,
        },
    };

    # Calculcate the results of the rules.
    $data->{wait_minutes}{can_build}     = $data->{wait_minutes}{required}   <=  $data->{wait_minutes}{current}  ? 1 : 0;
    $data->{builds_over_hour}{can_build} = $data->{builds_over_hour}{allowed} >  $data->{builds_over_hour}{used} ? 1 : 0;
    $data->{builds_over_day}{can_build}  = $data->{builds_over_day}{allowed}  >  $data->{builds_over_day}{used}  ? 1 : 0;

    # If all limits can build, we're good.
    $data->{can_build} = (
        $data->{wait_minutes}{can_build} && $data->{builds_over_hour}{can_build} && $data->{builds_over_day}{can_build}
            ? 1
            : 0
    );

    return $data;
}

1;
