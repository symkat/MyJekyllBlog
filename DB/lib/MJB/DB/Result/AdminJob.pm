use utf8;
package MJB::DB::Result::AdminJob;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::AdminJob

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

=head1 TABLE: C<admin_job>

=cut

__PACKAGE__->table("admin_job");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'admin_job_id_seq'

=head2 minion_job_id

  data_type: 'integer'
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
    sequence          => "admin_job_id_seq",
  },
  "minion_job_id",
  { data_type => "integer", is_nullable => 0 },
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-09 14:53:07
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:cBdbwYX0+0iPbxVol0Iskg

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id            => $self->id,
        minion_job_id => $self->minion_job_id,
        created_at    => $self->created_at->strftime( '%F %T' ),
    };
}

1;
