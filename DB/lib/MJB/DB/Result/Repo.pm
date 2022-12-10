use utf8;
package MJB::DB::Result::Repo;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

MJB::DB::Result::Repo

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

=head1 TABLE: C<repo>

=cut

__PACKAGE__->table("repo");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0
  sequence: 'repo_id_seq'

=head2 blog_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 url

  data_type: 'text'
  is_nullable: 0

=head2 basic_auth_id

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 1

=head2 ssh_key_id

  data_type: 'integer'
  is_foreign_key: 1
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
    sequence          => "repo_id_seq",
  },
  "blog_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "url",
  { data_type => "text", is_nullable => 0 },
  "basic_auth_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
  "ssh_key_id",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 1 },
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

=head2 basic_auth

Type: belongs_to

Related object: L<MJB::DB::Result::BasicAuth>

=cut

__PACKAGE__->belongs_to(
  "basic_auth",
  "MJB::DB::Result::BasicAuth",
  { id => "basic_auth_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 blog

Type: belongs_to

Related object: L<MJB::DB::Result::Blog>

=cut

__PACKAGE__->belongs_to(
  "blog",
  "MJB::DB::Result::Blog",
  { id => "blog_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);

=head2 ssh_key

Type: belongs_to

Related object: L<MJB::DB::Result::SshKey>

=cut

__PACKAGE__->belongs_to(
  "ssh_key",
  "MJB::DB::Result::SshKey",
  { id => "ssh_key_id" },
  {
    is_deferrable => 0,
    join_type     => "LEFT",
    on_delete     => "NO ACTION",
    on_update     => "NO ACTION",
  },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2022-09-15 21:45:36
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:1W7mgkNfoG1qrxdg7YXdrw

sub as_hashref {
    my ( $self ) = @_;

    return +{
        id            => $self->id,
        blog_id       => $self->blog_id,
        url           => $self->url,
        basic_auth_id => $self->basic_auth_id,
        ssh_key_id    => $self->ssh_key_id,
        created_at    => $self->created_at->strftime( '%F %T' ),
    };
}

1;
