package Server::Control::Plugin::FileWatcher;
use File::Basename;
use File::ChangeNotify;
use File::Slurp;
use List::MoreUtils qw(uniq);
use Log::Any qw($log);
use Moose::Role;
use Moose::Util::TypeConstraints;
use Time::HiRes qw(usleep);
use strict;
use warnings;

our $VERSION = '0.01';

has 'watcher_auto_watch' => ( is => 'ro', isa => 'Bool', default => 1 );
has 'watcher_notify' =>
  ( is => 'bare', required => 1, isa => 'Object|HashRef' );
has 'watcher_sleep_interval' => ( is => 'ro', isa => 'Num', default => 2 );
has 'watcher_trigger_method' =>
  ( is => 'ro', isa => 'Str|CodeRef', default => 'restart' );

after 'successful_start' => sub {
    my $self = shift;

    if ( $self->watcher_auto_watch ) {
        $self->watch();
    }
};

override 'valid_cli_actions' => sub {
    return ( super(), qw(watch) );
};

# Lazily convert watcher_notify params hash into object
#
sub watcher_notify {
    my $self = shift;
    if ( ref( $self->{watcher_notify} ) eq 'HASH' ) {
        $self->{watcher_notify} = File::ChangeNotify->instantiate_watcher(
            %{ $self->{watcher_notify} } );
    }
    return $self->{watcher_notify};
}

sub watch {
    my $self = shift;

    # Avoid entering more than once
    #
    return if $self->{watcher_in_watch};
    local $self->{watcher_in_watch} = 1;

    $log->info( "watching directories: "
          . join( ", ", map { "'$_'" } @{ $self->watcher_notify->directories } )
    );

    while (1) {

        # Check if any files changed. If so, run trigger; otherwise, sleep and try again.
        #
        if ( my @events = $self->watcher_notify->new_events() ) {
            my @paths =
              sort( grep { $self->is_valid_file($_) }
                  uniq( map { $_->path } @events ) );
            if (@paths) {
                $log->info( sprintf( "changes: %s", join( ", ", @paths ) ) );
                $self->watcher_trigger();
                $log->info("ready");
            }
        }
        else {
            usleep( $self->watcher_sleep_interval() * 1_000_000 );
        }
    }
}

# Borrowed from Plack::Loader::Restarter
#
sub is_valid_file {
    my ($file) = @_;
    $file !~ m![/\\][\._]|\.bak$|~$!;
}

sub watcher_trigger {
    my $self   = shift;
    my $method = $self->watcher_trigger_method;
    $self->$method();
}

1;

__END__

=pod

=head1 NAME

Server::Control::Plugin::FileWatcher -- Take server action on file/directory
change

=head1 SYNOPSIS

    use Server::Control::Plugin::FileWatcher;

    # Auto-watch after successful start
    #
    % apachectlp -k start
    waiting for server start
    watching directories: lib
    ...
    changes: lib/Foo.pm
    sent HUP to process 28575
    waiting for server restart
    server 'hm' is running (pid 28575) and listening to port 3220
    ready

    # Manual watch
    #
    % apachectlp -k watch
    watching directories: lib
    ...

=head1 DESCRIPTION

Server::Control::Plugin::FileWatcher creates a new action, 'watch', that
perpetually watches particular files/directories for changes and perform a
server action (e.g. restart) on each change.

By default 'watch' is automatically called after a successful server start.

=head1 PARAMETERS

=over

=item watcher_notify

A File::ChangeNotify object, or a hashref of File::ChangeNotify constructor
parameters, indicating which files/directories to watch. Required.

=item watcher_auto_watch

Indicates whether 'watch' should be automatically called after a successful
server start. Defaults to true.

=item watcher_sleep_interval

Number of seconds (floating point) to sleep between checks. Defaults to 0.5.

=item watcher_trigger_method

A method name or a code ref to call when files/directories change. Defaults to 'restart'.

=back

=head1 AUTHOR

Jonathan Swartz

=head1 SEE ALSO

L<Server::Control|Server::Control>, L<File::ChangeNotify|File::ChangeNotify>

=head1 COPYRIGHT & LICENSE

Copyright (C) 2007 Jonathan Swartz.

Server::Control::Plugin::FileWatcher is provided "as is" and without any
express or implied warranties, including, without limitation, the implied
warranties of merchantibility and fitness for a particular purpose.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
