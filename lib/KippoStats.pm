package KippoStats;

use strict;
use warnings;

use lib './lib';
use base 'Mojolicious';
use KippoStats::DB::Schema;

sub startup {
    my $self = shift;

    my $config = $self->plugin('json_config');    # kippo_stats.json
    die "Need dsn in kippo_stats.json" unless exists $config->{dsn};
    die "Need username in kippo_stats.json" unless exists $config->{username};
    die "Need password in kippo_stats.json" unless exists $config->{password};

    my $db = KippoStats::DB::Schema->connect( $config->{dsn}, $config->{username}, $config->{password} );

    if (!$self->can('model')) {
        ref($self)->attr( model => sub { $db }, );
    }

    my $r = $self->routes;
    $r->route('/stats')->to('stats#index');
    $r->route('/stats/sessions/count/:since')->to('stats#sessions_count');
    $r->route('/stats/sessions/img/:since')->to('stats#sessions_img');
    $r->route('/stats/sessions/')->to('stats#sessions');
    $r->route('/stats/successful_auth/count/:since')->to('stats#successful_auth_count');
    $r->route('/stats/successful_auth/img/:since')->to('stats#successful_auth_img');
    $r->route('/stats/successful_auth/')->to('stats#successful_auth');
}

1;
