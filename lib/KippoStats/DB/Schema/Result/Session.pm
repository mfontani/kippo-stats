package KippoStats::DB::Schema::Result::Session;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

KippoStats::DB::Schema::Result::Session

=cut

__PACKAGE__->table("sessions");

=head1 ACCESSORS

=head2 id

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 starttime

  data_type: 'datetime'
  is_nullable: 0

=head2 endtime

  data_type: 'datetime'
  is_nullable: 1

=head2 sensor

  data_type: 'integer'
  is_nullable: 0

=head2 ip

  data_type: 'varchar'
  default_value: (empty string)
  is_nullable: 0
  size: 15

=head2 termsize

  data_type: 'varchar'
  is_nullable: 1
  size: 7

=head2 client

  data_type: 'integer'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "char", is_nullable => 0, size => 32 },
  "starttime",
  { data_type => "datetime", is_nullable => 0 },
  "endtime",
  { data_type => "datetime", is_nullable => 1 },
  "sensor",
  { data_type => "integer", is_nullable => 0 },
  "ip",
  { data_type => "varchar", default_value => "", is_nullable => 0, size => 15 },
  "termsize",
  { data_type => "varchar", is_nullable => 1, size => 7 },
  "client",
  { data_type => "integer", is_nullable => 1 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 19:50:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:zrCcvFWU/BK9cPKYzztcGw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
