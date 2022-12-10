use utf8;
package MJB::DB::Result::HostedDomain;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::HostedDomain

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

=head1 TABLE: C<hosted_domain>

=cut

__PACKAGE__->table("hosted_domain");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'hosted_domain_id_seq'

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 letsencrypt_challenge

  data_type: 'text'
  default_value: 'http'
  is_nullable: 0

=head2 letsencrypt_dns_auth

  data_type: 'json'
  default_value: '{}'
  is_nullable: 0
  serializer_class: 'JSON'

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
    sequence          => "hosted_domain_id_seq",
  },
  "name",
  { data_type => "text", is_nullable => 0 },
  "letsencrypt_challenge",
  { data_type => "text", default_value => "http", is_nullable => 0 },
  "letsencrypt_dns_auth",
  {
    data_type        => "json",
    default_value    => "{}",
    is_nullable      => 0,
    serializer_class => "JSON",
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


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-11-04 18:27:03
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:Jn80IGZYKR1o1cMoeUGPYQ

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id                    => $self->id,
        name                  => $self->name,
        letsencrypt_challenge => $self->letsencrypt_challenge,
        letsencrypt_dns_auth  => $self->letsencrypt_dns_auth,
        created_at            => $self->created_at->strftime( '%F %T' ),
    };
}

1;
