#!perl
use Test::More;
use File::Path;
use File::Slurp;
use File::Temp qw(tempdir);
use File::Which;
use Guard;
use IPC::System::Simple qw(run);
use Log::Log4perl;
use POSIX qw(geteuid getegid);
use Server::Control::Util qw(get_child_pids kill_my_children);
use Server::Control::NetServer;
use Time::HiRes qw(usleep);
use strict;
use warnings;

$SIG{CHLD} = 'IGNORE';

plan(tests => 8);

# How to pick this w/o possibly conflicting...
my $port        = 15432;
my $server_root = tempdir( 'Server-Control-XXXX', DIR => '/tmp', CLEANUP => 1 );
my $lib_dir     = "$server_root/lib";
my $lib_file    = "$lib_dir/Foo.pm";
mkpath( $lib_dir, 0, 0775 );
write_file( $lib_file, "Foo" );

my $ctl = Server::Control::NetServer->new_with_traits(
    net_server_class  => 'Net::Server::PreForkSimple',
    server_root  => $server_root,
    net_server_params => {
        max_servers => 2,
        port        => $port,
        pid_file    => $server_root . "/server.pid",
        log_file    => $server_root . "/server.log",
        user        => geteuid(),
        group       => getegid()
    },
    traits  => ['FileWatcher'],
    watcher_notify => { directories => [$lib_dir], sleep_interval => 1 },
    watcher_verbose => 1,
#    useful for test debugging
#    watcher_log_file => './watcher.log',
);

my $parent_pid = $$;
my $stop_guard = guard( sub { cleanup() if $$ == $parent_pid } );

ok( $ctl->start(), 'started' );
my $server_pid = $ctl->is_running->pid;
my $watcher_pid  = $ctl->watcher_pid;
ok(defined($watcher_pid), "watcher started - $watcher_pid");

my @pids = wait_for_child_pids( $server_pid );
ok( @pids >= 1, "at least one child pid - " . join(", ", @pids));

write_file( $lib_file, "Bar" );

usleep(500000);  # wait for pids to die
my @pids2 = wait_for_child_pids( $server_pid );
ok( @pids2 >= 1, "at least one child pid after refork - " . join(", ", @pids2));
my %in_pids = map { ( $_, 1 ) } @pids;
ok( !(grep { $in_pids{$_} } @pids2), "none of pids2 are in pids" );

ok(kill(0, $watcher_pid), "watcher (pid $watcher_pid) still running");
ok($ctl->stop(), 'stopped');
for my $count ( 0 .. 50 ) {
    last if !kill(0, $watcher_pid);
    usleep(100000);
}
ok(!kill(0, $watcher_pid), "watcher (pid $watcher_pid) stopped");

sub wait_for_child_pids {
    my ($pid) = @_;
    my @child_pids;
    for my $count ( 0 .. 9 ) {
        Time::HiRes::sleep(0.5);
        last if @child_pids = get_child_pids($pid);
    }
    return @child_pids;
}

sub cleanup {
    if ( $ctl->is_running() ) {
        $ctl->stop();
    }
    kill(15, $watcher_pid) if $watcher_pid;
    kill_my_children();
}
