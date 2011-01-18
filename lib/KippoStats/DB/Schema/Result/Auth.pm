package KippoStats::DB::Schema::Result::Auth;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

use strict;
use warnings;

use base 'DBIx::Class::Core';


=head1 NAME

KippoStats::DB::Schema::Result::Auth

=cut

__PACKAGE__->table("auth");

=head1 ACCESSORS

=head2 id

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 session

  data_type: 'char'
  is_nullable: 0
  size: 32

=head2 success

  data_type: 'tinyint'
  is_nullable: 0

=head2 username

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 password

  data_type: 'varchar'
  is_nullable: 0
  size: 100

=head2 timestamp

  data_type: 'datetime'
  is_nullable: 0

=cut

__PACKAGE__->add_columns(
  "id",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "session",
  { data_type => "char", is_nullable => 0, size => 32 },
  "success",
  { data_type => "tinyint", is_nullable => 0 },
  "username",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "password",
  { data_type => "varchar", is_nullable => 0, size => 100 },
  "timestamp",
  { data_type => "datetime", is_nullable => 0 },
);
__PACKAGE__->set_primary_key("id");


# Created by DBIx::Class::Schema::Loader v0.07002 @ 2011-01-17 19:50:47
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:YBttQif3xHq2z/junAkRAw


# You can replace this text with custom content, and it will be preserved on regeneration
1;
