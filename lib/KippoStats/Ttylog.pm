package KippoStats::Ttylog;

use strict;
use warnings;

use lib './lib';
use base 'Mojolicious::Controller';
use KippoStats::DB::Schema;

sub index {
    my $self = shift;

    my $model = $self->app->model;

    my @ttylogs = $model->resultset('Ttylog')->search(
        {
        },
        {
            select => [
                'id', 'session',
                { length => 'ttylog', '-as' => 'length_ttylog' },
            ],
            as => [ qw/id session length_ttylog/ ],
            order_by => { -desc => 'id' },
            join => 'ssh_session',
        }
    );

    $self->stash( ttylogs => \@ttylogs );

    $self->render()
}

sub ttylog {
    my $self = shift;

    my $model = $self->app->model;

    my @ttylog = $model->resultset('Ttylog')->search(
        {
            session => $self->param('session')
        },
        {
            select => [
                qw/id session ttylog/,
                { length => 'ttylog', '-as' => 'length_ttylog' },
            ],
            as => [ qw/id session ttylog length_ttylog/ ],
            order_by => { -desc => 'id' },
            join => 'ssh_session',
        }
    );

    my $bare_ttylog = @ttylog ? $ttylog[0]->ttylog : '';
    my @lines_ttylog = tty_log_to_arrayrefs($bare_ttylog);

    $self->stash(
        ttylog       => $ttylog[0],
        lines_ttylog => \@lines_ttylog,
        bare_ttylog  => $bare_ttylog,
    );

    $self->render()
}

sub tty_log_to_arrayrefs
{
    my ($bare_ttylog) = @_;

    my @lines;

    ## Convert TTY log to arrayrefs
    my ($OP_OPEN,$OP_CLOSE,$OP_WRITE,$OP_EXEC) = (1..4);
    my ($DIR_READ,$DIR_WRITE) = (1,2);
    my ($curtty,$prevtime,$prefdir) = (0,0,0);
    my $ssize = length(pack('iLiiLL',0,0,0,0,0));
    my $curpos = 0;
    my $nlines = 0;
    while (1) {
        my ($op,$tty,$length,$dir,$sec,$usec) = unpack('iLiiLL', substr($bare_ttylog,$curpos,$ssize));
        warn "CURPOS $curpos OP $op TTY $tty LENGTH $length DIR $dir SEC $sec USEC $usec:\n";
        $curpos += $ssize;
        my $data = substr($bare_ttylog,$curpos,$length);
        warn "CURPOS $curpos: data $data\n";
        $curpos += $length;
        $curtty = $tty if ( $curtty == 0 );
        my $sleeptime = 0.0;
        if ( $curtty == $tty and $op == $OP_WRITE ) {
            if ( $prefdir == 0 ) {
                $prefdir = $dir;
            }
            my $curtime = $sec*1.0 + $usec/100_000;
            if ( $prevtime ) {
                $sleeptime = $curtime*1.0 - $prevtime*1.0;
                $sleeptime = 2.0 if $sleeptime > 2.0;
            }
            $prevtime = $curtime;
        }
        warn "Sleeptime $sleeptime\n";

        # munge data
        $data =~ s,\e,\[ESC\],g;
        $data =~ s,\x0d,\[RE\],g;
        $data =~ s,\x0a,\[NL\],g;
        $data =~ s,\x7f,\[DEL\],g;

        last if ( $op eq '' and $tty eq '' and $length eq '' and $dir eq '' and $sec eq '' );
        #push @lines, [ $op, $tty, $length, $dir, $sec, $usec, $sleeptime, $data ]
        push @lines, [ $length, $sleeptime, $data, $dir ]
            #unless $dir == $DIR_READ
            ;
        last if ( $tty == $curtty and $op == $OP_CLOSE );
        $nlines++;
        $nlines > 5_000 and do {
            warn "TOO MANY LINES";
            last;
        };
    }
    return @lines;
}

1;
