package KippoStats::Stats;

use strict;
use warnings;

use lib './lib';
use base 'Mojolicious::Controller';
use KippoStats::DB::Schema;
use Date::Calc qw/Today Delta_Days Add_Delta_Days/;
use List::Util qw/max/;
use Chart::Strip;
use Date::Parse;

our $default_image_width  = 420;
our $default_image_height = 220;

# Colours for graphs with more than one line
# Ordered from least to most
our @colours = (qw/
    99CC00 0099CC CCCC33 FF4775 FF0033
    99CC00 0099CC CCCC33 FF4775 FF0033
/);

# Createsa PNG from the query parameters and details given
sub _stats_to_png
{
    my (
        $self,
        $table,
        $search_terms,
        $timestamp,
        $minutes_interval,
        $title,
        $label,
    ) = @_;

    my $model = $self->app->model;

    my @sessions = $model->resultset($table)->search( @$search_terms );
    my %sessions_by_day_and_hour;
    my @earliest_date = Today();
    for my $conn (@sessions) {
        my ($ymd,$hms) = split(' ', $conn->$timestamp);
        my @ymd = split('-', $ymd);
        @earliest_date = @ymd if (
            $ymd[0] <= $earliest_date[0] &&
            $ymd[1] <= $earliest_date[1] &&
            $ymd[2] <= $earliest_date[2]
        );
        my ($h,$m) = split(':', $hms);
        my $ymdhms = sprintf("$ymd $h:%02d:00", int($m/$minutes_interval));
        my $time = str2time($ymdhms);
        $sessions_by_day_and_hour{$time}+= $conn->get_column('cnt');
    }

    # flatten them by hour/$minutes_interval
    my $dd = Delta_Days( @earliest_date, Today());
    my @curr_ymd = map { sprintf("%02d",$_) } Add_Delta_Days( Today(), -$dd );
    my @latest_date = map { sprintf("%02d",$_) } Today();
    my @minutes_interval = map { $_*$minutes_interval } 0..(int(60/$minutes_interval)-1);
    while ( "@curr_ymd" le "@latest_date" ) {
        for ( my $h = 0; $h <= 23; $h++ ) {
            for my $m ( @minutes_interval ) {
                my $ymdhms = sprintf("%04d-%02d-%02d %02d:%02d:00", @curr_ymd, $h, $m);
                my $time = str2time($ymdhms);
                $sessions_by_day_and_hour{$time} = 0 if !exists $sessions_by_day_and_hour{$time};
            }
        }
        $dd--;
        @curr_ymd = map { sprintf("%02d",$_) } Add_Delta_Days( @latest_date, -$dd );
    }

    my $chart = Chart::Strip->new(
        title => $title,
        min => 0,
        draw_tic_labels => 1,
        draw_data_labels => 1,
        transparent => 0,
        skip_undefined => 0,
        width => $default_image_width, height => $default_image_height,
    );
    my @data = map +{
                time => $_,
                value => $sessions_by_day_and_hour{$_}
            }, sort keys %sessions_by_day_and_hour;
    $chart->add_data( \@data, { label => $label, color => 'AA9090', }, );
    $chart->set_y_range(0);
    return $chart->png();
}

# Creates PNG from the query parameters, aggregated for the topmost entities
sub _topmost_to_png
{
    my (
        $self,
        $table,
        $other_where_clauses,
        $since,
        $minutes_interval,
        $topmost,
        $title,
        $timestamp,
        $attribute,
    ) = @_;

    my $model = $self->app->model;

    my @dbtopmost = $model->resultset($table)->search(
        { $timestamp => { '>=', $since }, @$other_where_clauses, },
        {
            select => [
                { count => '*', '-as' => 'cnt' },
                $attribute,
            ],
            as => [ 'cnt', $attribute ],
            group_by => $attribute,
            order_by => { -desc => 'cnt' },
            rows => $topmost,
        }
    );

    my %most_by_attribute = map { $_->$attribute, $_->get_column('cnt') } @dbtopmost;

    my @dbdata = $model->resultset($table)->search(
        {
            $timestamp => { '>=', $since },
            $attribute => { 'IN' => [ keys %most_by_attribute ], },
        },
        {
            select => [ { count => '*', -as => 'cnt' }, $attribute, $timestamp ],
            as => [ 'cnt', $attribute, $timestamp ],
            group_by => "$attribute,date($timestamp),hour($timestamp),floor(minute($timestamp)/$minutes_interval)",
        },
    );

    my %stats;
    my @earliest_date = Today();
    for my $datum (@dbdata) {
        my ($ymd,$hms) = split(' ', $datum->$timestamp);
        my @ymd = split('-', $ymd);
        @earliest_date = @ymd if (
            $ymd[0] <= $earliest_date[0] &&
            $ymd[1] <= $earliest_date[1] &&
            $ymd[2] <= $earliest_date[2]
        );
        my ($h,$m) = split(':', $hms);
        my $ymdhms = sprintf("$ymd $h:%02d:00", int($m/$minutes_interval));
        my $time = str2time($ymdhms);
        $stats{ $datum->$attribute }{$time}+= $datum->get_column('cnt');
    }

    # flatten them by hour/$minutes_interval
    my $dd = Delta_Days( @earliest_date, Today());
    my @curr_ymd = map { sprintf("%02d",$_) } Add_Delta_Days( Today(), -$dd );
    my @latest_date = map { sprintf("%02d",$_) } Today();
    my @minutes_interval = map { $_*$minutes_interval } 0..(int(60/$minutes_interval)-1);
    my @attributes = keys %stats;
    while ( "@curr_ymd" le "@latest_date" ) {
        for ( my $h = 0; $h <= 23; $h++ ) {
            for my $entity (@attributes) {
                for my $m ( @minutes_interval ) {
                    my $ymdhms = sprintf("%04d-%02d-%02d %02d:%02d:00", @curr_ymd, $h, $m);
                    my $time = str2time($ymdhms);
                    $stats{$entity}{$time} = 0 if !exists $stats{$entity}{$time};
                }
            }
        }
        $dd--;
        @curr_ymd = map { sprintf("%02d",$_) } Add_Delta_Days( @latest_date, -$dd );
    }

    my $chart = Chart::Strip->new(
        title => $title,
        min => 0,
        draw_tic_labels => 1,
        draw_data_labels => 1,
        transparent => 0,
        skip_undefined => 0,
        width => $default_image_width, height => $default_image_height,
    );
    my $coloridx = 0;
    for my $entity (
        grep defined,
        ( sort { $most_by_attribute{$b} <=> $most_by_attribute{$a} } keys %most_by_attribute )
          [ 0 .. ( $topmost - 1 ) ]
      )
    {
        my @data = map +{
                    time => $_,
                    value => $stats{$entity}{$_}
                }, sort keys %{$stats{$entity}};
        $chart->add_data(
            \@data,
            {
                label => "$entity ($most_by_attribute{$entity})",
                color => ( $colours[$#colours-$coloridx] || 'AA9090' ),
            },
        );
        $coloridx++;
    }
    $chart->set_y_range(0);
    return $chart->png();

}

# PNG image for stats about successful auth
sub successful_auth_img
{
    my $self = shift;

    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $interval = $self->param('interval');
    $interval = 30 if !defined $interval;
    if ( $interval !~ /^\d+$/ ) {
        return $self->render( text => 'Provide interval in NNN format please', status => 500 );
    }
    if ( $interval < 10 or $interval > 60 ) {
        return $self->render( text => 'Interval must be between 10 and 60, inclusive', status => 500 );
    }

    my $png = $self->_stats_to_png( 'Auth',
        [
            { timestamp => { '>=', $since }, success => 1 },
            {
                select => [ { count => '*' }, 'timestamp' ],
                as     => [qw/cnt timestamp/],
                group_by => "date(timestamp),hour(timestamp),floor(minute(timestamp)/$interval)",
            }
        ],
        'timestamp',
        $interval,
        "Successful auth per $interval minutes since $since",
        'Successful Auth',
    );

    $self->render_data($png, format => 'png');

}

# PNG image for stats about usernames used for auth
sub usernames_auth_img
{
    my $self = shift;

    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $interval = $self->param('interval');
    $interval = 30 if !defined $interval;
    if ( $interval !~ /^\d+$/ ) {
        return $self->render( text => 'Provide interval in NNN format please', status => 500 );
    }
    if ( $interval < 10 or $interval > 60 ) {
        return $self->render( text => 'Interval must be between 10 and 60, inclusive', status => 500 );
    }
    my $topmost = $self->param('topmost');
    $topmost = 5 if !defined $topmost;
    if ( $topmost !~ /^\d+$/ ) {
        return $self->render( text => 'Provide topmost in NNN format please', status => 500 );
    }
    if ( $topmost < 1 or $topmost > 10 ) {
        return $self->render( text => 'topmost must be between 1 and 10, inclusive', status => 500 );
    }

    my $png =
      $self->_topmost_to_png( 'Auth', [], $since, $interval, $topmost,
        "Top $topmost usernames per $interval minutes since $since",
        'timestamp', 'username', );

    $self->render_data($png, format => 'png');

}

# PNG image for stats about passwords used for auth for a specific username
sub passwords_auth_img
{
    my $self = shift;

    my $username = $self->param('username');
    if ( !$username or !length $username or $username !~ /^[a-z0-9]+$/i ) {
        return $self->render( text => 'Provide username (letters and numbers only) please', status => 500 );
    }
    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $interval = $self->param('interval');
    $interval = 30 if !defined $interval;
    if ( $interval !~ /^\d+$/ ) {
        return $self->render( text => 'Provide interval in NNN format please', status => 500 );
    }
    if ( $interval < 10 or $interval > 60 ) {
        return $self->render( text => 'Interval must be between 10 and 60, inclusive', status => 500 );
    }
    my $topmost = $self->param('topmost');
    $topmost = 5 if !defined $topmost;
    if ( $topmost !~ /^\d+$/ ) {
        return $self->render( text => 'Provide topmost in NNN format please', status => 500 );
    }
    if ( $topmost < 1 or $topmost > 10 ) {
        return $self->render( text => 'topmost must be between 1 and 10, inclusive', status => 500 );
    }

    my $png =
      $self->_topmost_to_png( 'Auth', [ username => { '=' => $username } ], $since, $interval, $topmost,
        "Top $topmost passwords for $username per $interval minutes since $since",
        'timestamp', 'password', );

    $self->render_data($png, format => 'png');

}

# text: how many successful auths since the date given?
sub successful_auth_count
{
    my $self = shift;

    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $model = $self->app->model;

    my $cnt = $model->resultset('Auth')->search(
        { timestamp => { '>=', $since }, success => 1 },
        {
            select => [ { count => '*' } ],
            as     => [qw/cnt/],
        }
    )->count();

    $self->render( text => $cnt );
}

# PNG image for stats about total sessions (attempts)
sub sessions_img
{
    my $self = shift;

    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $interval = $self->param('interval');
    $interval = 30 if !defined $interval;
    if ( $interval !~ /^\d+$/ ) {
        return $self->render( text => 'Provide interval in NNN format please', status => 500 );
    }
    if ( $interval < 10 or $interval > 60 ) {
        return $self->render( text => 'Interval must be between 10 and 60, inclusive', status => 500 );
    }

    my $png = $self->_stats_to_png( 'Session',
        [
            { starttime => { '>=', $since } },
            {
                select => [ { count => '*' }, 'starttime' ],
                as     => [qw/cnt starttime/],
                group_by => "date(starttime),hour(starttime),floor(minute(starttime)/$interval)",
            }
        ],
        'starttime',
        $interval,
        "Sessions per $interval minutes since $since",
        'Sessions',
    );

    $self->render_data($png, format => 'png');
}

# text: how many sessions since the date given?
sub sessions_count
{
    my $self = shift;

    my $since = $self->param('since');
    if ( $since !~ /^\d{4}-\d{2}-\d{2}$/ ) {
        return $self->render( text => 'Provide date in YYYY-MM-DD format please', status => 500 );
    }
    my $model = $self->app->model;

    my $cnt = $model->resultset('Session')->search(
        { starttime => { '>=', $since } },
        {
            select => [ { count => '*' } ],
            as     => [qw/cnt/],
        }
    )->count();

    $self->render( text => $cnt );
}

# Renders the global statistics page
sub index {
    my $self = shift;

    $self->render()
}

sub sessions {
    my $self = shift;
    $self->render()
}

sub successful_auth  {
    my $self = shift;
    $self->render()
}

sub usernames_auth  {
    my $self = shift;
    $self->render()
}

sub passwords_auth  {
    my $self = shift;
    $self->render()
}

1;
