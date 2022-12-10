use utf8;
package MJB::DB::Result::SystemNote;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::SystemNote

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

=head1 TABLE: C<system_note>

=cut

__PACKAGE__->table("system_note");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'system_note_id_seq'

=head2 is_read

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 source

  data_type: 'text'
  is_nullable: 1

=head2 content

  data_type: 'text'
  is_nullable: 1

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
    sequence          => "system_note_id_seq",
  },
  "is_read",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "source",
  { data_type => "text", is_nullable => 1 },
  "content",
  { data_type => "text", is_nullable => 1 },
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-09 15:14:54
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zJbvo73sRKwhcGgq5h4TYw

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id         => $self->id,
        is_read    => $self->is_read,
        source     => $self->source,
        content    => $self->content,
        created_at => $self->created_at->strftime( '%F %T' ),
    };
}

1;
