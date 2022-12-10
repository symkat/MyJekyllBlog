use utf8;
package MJB::DB::Result::Domain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::Domain

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

=head1 TABLE: C<domain>

=cut

__PACKAGE__->table("domain");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'domain_id_seq'

=head2 person_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 name

  data_type: 'citext'
  is_nullable: 0

=head2 ssl

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
    sequence          => "domain_id_seq",
  },
  "person_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "name",
  { data_type => "citext", is_nullable => 0 },
  "ssl",
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

=head1 UNIQUE CONSTRAINTS

=head2 C<domain_name_key>

=over 4

=item * L</name>

=back

=cut

__PACKAGE__->add_unique_constraint("domain_name_key", ["name"]);

=head1 RELATIONS

=head2 blogs

Type: has_many

Related object: L<MJB::DB::Result::Blog>

=cut

__PACKAGE__->has_many(
  "blogs",
  "MJB::DB::Result::Blog",
  { "foreign.domain_id" => "self.id" },
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-06 19:24:12
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:agNtunaurulCvfqzy39meg

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id         => $self->id,
        person_id  => $self->person_id,
        name       => $self->name,
        ssl        => $self->ssl,
        created_at => $self->created_at->strftime( '%F %T' ),
    };
}

1;
