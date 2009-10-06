package Server::Control::Plugin::FileWatcher::Watcher;
use strict;
use warnings;
use File::Basename;
use File::Slurp;
use Guard;
use Log::Any qw($log);
use Moose;
use Proc::Daemon;
use Time::HiRes qw(usleep);

our $VERSION = '0.01';

has 'ctl'            => ( is => 'ro', required => 1 );
has 'log_file'       => ( is => 'ro', required => 1 );
has 'notify'         => ( is => 'ro', required => 1 );
has 'pid_file'       => ( is => 'ro', required => 1 );
has 'sleep_interval' => ( is => 'ro', required => 1 );
has 'verbose'        => ( is => 'ro', required => 1 );

__PACKAGE__->meta->make_immutable();

sub start {
    my $self = shift;

    my $log_file = $self->log_file;
    my $pid_file = $self->pid_file;

    my $proc = $self->ctl->is_running()
      or die sprintf( "huh? %s not running", $self->ctl->description );
    my $ppid = $proc->pid;

    # Fork and daemonise
    return if fork();
    Proc::Daemon::Init();

    # Write pid file, remove on exit
    write_file( $pid_file, $$ );
    scope_guard { unlink($pid_file) };

    # Send our logs, and any Log::Any logs, to $log_file
    unlink($log_file);
    my $log = Log::Dispatch->new(
        outputs => [
            [
                'File',
                min_level => $self->verbose ? 'debug' : 'info',
                filename  => $log_file,
                newline   => 1
            ],
        ]
    );
    Log::Any->set_adapter( 'Dispatch', dispatcher => $log );

    $log->info( sprintf( "watcher for %s starting", $self->ctl->description ) );
    my $is_debug = $self->verbose;

    while (1) {

        # Check if server is still running; if not, exit.
        #
        my $proc = $self->ctl->is_running();
        if ( !$proc || $proc->pid != $ppid ) {
            $log->info(
                sprintf( "%s no longer running, watcher exiting",
                    $self->ctl->description )
            );
            exit;
        }

        # Check if any files changed. If so, refork; otherwise, sleep and try again.
        #
        if ( my @events = $self->notify->new_events() ) {
            $log->debug(
                sprintf(
                    "watcher received events: %s",
                    join( ", ",
                        map { join( ":", $_->path, $_->type ) } @events )
                )
            ) if $is_debug;
            my @child_pids = $self->ctl->refork();
            $log->debug(
                sprintf(
                    "watcher sent TERM to children of pid %d (%s)",
                    $ppid, join( ", ", @child_pids )
                )
            ) if $is_debug;
        }
        else {
            usleep( $self->sleep_interval() * 1_000_000 );
        }
    }
}

1;
