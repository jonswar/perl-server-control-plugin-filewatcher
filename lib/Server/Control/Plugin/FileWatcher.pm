package Server::Control::Plugin::FileWatcher;
use File::Basename;
use File::ChangeNotify;
use File::Slurp;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Server::Control::Plugin::FileWatcher::Watcher;
use Time::HiRes qw(usleep);
use strict;
use warnings;

our $VERSION = '0.01';

my $cn_type = subtype as class_type('File::ChangeNotify::Watcher');
coerce $cn_type => from 'HashRef' =>
  via { File::ChangeNotify->instantiate_watcher( %{$_} ) };

has 'watcher_log_file' => ( is => 'ro', lazy_build => 1 );
has 'watcher_notify'   => ( is => 'ro', isa        => $cn_type, coerce => 1 );
has 'watcher_pid'      => ( is => 'ro', init_arg   => undef );
has 'watcher_sleep_interval' => ( is => 'ro', isa => 'Num', default => 2 );
has 'watcher_verbose' => ( is => 'ro' );

after 'successful_start' => sub {
    my $self             = shift;
    my $watcher_pid_file = dirname( $self->pid_file ) . "/watcher.pid.$$";
    if ( -f $watcher_pid_file ) {
        warn
          "watcher pid file '$watcher_pid_file' already exists - not creating another one";
        return;
    }
    my $watcher = Server::Control::Plugin::FileWatcher::Watcher->new(
        pid_file       => $watcher_pid_file,
        verbose        => $self->watcher_verbose,
        log_file       => $self->watcher_log_file,
        notify         => $self->watcher_notify,
        sleep_interval => $self->watcher_sleep_interval,
        ctl            => $self
    );
    $watcher->start();
    for my $i ( 0 .. 5 ) {
        last if -f $watcher_pid_file;
        usleep(250000);
    }
    if ( -f $watcher_pid_file ) {
        $self->{watcher_pid} = read_file($watcher_pid_file);
    }
    else {
        die
          "could not start watcher - pid file '$watcher_pid_file' was not created";
    }
};

sub _build_watcher_log_file {
    my ($self) = @_;

    return
      defined( $self->error_log )
      ? dirname( $self->error_log ) . "/watcher.log"
      : die "no log file and could not determine from error log";
}

1;

__END__

=pod

=head1 NAME

Server::Control::Plugin::FileWatcher -- Take server action on file/directory
change

=head1 SYNOPSIS

    use Server::Control::Plugin::FileWatcher;

=head1 DESCRIPTION

Server::Control::Plugin::FileWatcher launches a daemon to watch for particular
files/directories to change, and performs a server action (e.g. restart,
refork) when they do change.

=head1 AUTHOR

Jonathan Swartz

=head1 SEE ALSO

L<Server::Control>

=head1 COPYRIGHT & LICENSE

Copyright (C) 2007 Jonathan Swartz.

Server::Control::Plugin::FileWatcher is provided "as is" and without any
express or implied warranties, including, without limitation, the implied
warranties of merchantibility and fitness for a particular purpose.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
