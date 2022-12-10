use utf8;
package MJB::DB::Result::Subscription;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::Subscription

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

=head1 TABLE: C<subscription>

=cut

__PACKAGE__->table("subscription");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'subscription_id_seq'

=head2 person_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 stripe_customer_id

  data_type: 'text'
  is_nullable: 1

=head2 is_valid

  data_type: 'boolean'
  default_value: false
  is_nullable: 0

=head2 last_checked_at

  data_type: 'timestamp with time zone'
  default_value: current_timestamp
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
    sequence          => "subscription_id_seq",
  },
  "person_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "stripe_customer_id",
  { data_type => "text", is_nullable => 1 },
  "is_valid",
  { data_type => "boolean", default_value => \"false", is_nullable => 0 },
  "last_checked_at",
  {
    data_type     => "timestamp with time zone",
    default_value => \"current_timestamp",
    is_nullable   => 0,
  },
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

=head2 C<subscription_person_id_key>

=over 4

=item * L</person_id>

=back

=cut

__PACKAGE__->add_unique_constraint("subscription_person_id_key", ["person_id"]);

=head1 RELATIONS

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


# Created by DBIx::Class::Schema::Loader v0.07051 @ 2022-12-05 17:03:53
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:JCgARbPdOi4GeCGbqhLNow

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id                 => $self->id,
        person_id          => $self->person_id,
        stripe_customer_id => $self->stripe_customer_id,
        is_valid           => $self->is_valid,
        last_checked_at    => $self->last_checked_at->strftime( '%F %T' ),
        created_at         => $self->created_at->strftime( '%F %T' ),
    };
}
1;
