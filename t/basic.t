#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::Mojo;

use_ok('KippoStats');

# Test
my $t = Test::Mojo->new(app => 'KippoStats');
$t->get_ok('/stats/')->status_is(200)->content_type_is('text/html;charset=UTF-8');
