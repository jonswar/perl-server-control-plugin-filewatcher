package Server::Control::Plugin::FileWatcher;
use File::Basename;
use File::ChangeNotify;
use File::Slurp;
use Log::Any qw($log);
use Moose::Role;
use Moose::Util::TypeConstraints;
use Time::HiRes qw(usleep);
use strict;
use warnings;

our $VERSION = '0.01';

my $cn_type = subtype as class_type('File::ChangeNotify::Watcher');
coerce $cn_type => from 'HashRef' =>
  via { File::ChangeNotify->instantiate_watcher( %{$_} ) };

my $default_trigger_method = sub { $_[0]->restart };
has 'watcher_notify' => ( is => 'ro', isa => $cn_type, coerce => 1 );
has 'watcher_sleep_interval' => ( is => 'ro', isa => 'Num', default => 2 );
has 'watcher_trigger_method' =>
  ( is => 'ro', isa => 'Str|Code', default => 'restart' );

after 'successful_start' => sub {
    my $self = shift;
    $self->run_watcher();
};

sub watcher_run {
    my $self = shift;
    $log->info( "watching directories: "
          . join( ", ", map { "'$_'" } @{ $self->watcher_notify->directories } )
    );

    while (1) {

        # Check if server is still running; if not, exit.
        #
        my $proc = $self->is_running();
        if ( !$proc ) {
            $log->info(
                sprintf( "%s no longer running, watcher exiting",
                    $self->description )
            );
            last;
        }

        # Check if any files changed. If so, run trigger; otherwise, sleep and try again.
        #
        if ( my @events = $self->notify->new_events() ) {
            $log->debug(
                sprintf(
                    "watcher received events: %s",
                    join( ", ",
                        map { join( ":", $_->path, $_->type ) } @events )
                )
            ) if $is_debug;
            $self->watcher_trigger();
            $self->$method();
        }
        else {
            usleep( $self->sleep_interval() * 1_000_000 );
        }
    }
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

=head1 DESCRIPTION

Server::Control::Plugin::FileWatcher takes control after a successful server
start, and watches particular files/directories. When they change, it performs
a server action (e.g. restart, refork).

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
