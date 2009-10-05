package Server::Control::Plugin::PiedPiper;
use File::Basename;
use File::ChangeNotify;
use File::Slurp;
use Moose::Role;
use Moose::Util::TypeConstraints;
use Server::Control::Plugin::PiedPiper::Watcher;
use Time::HiRes qw(usleep);
use strict;
use warnings;

our $VERSION = '0.01';

my $cn_type = subtype as class_type('File::ChangeNotify::Watcher');
coerce $cn_type => from 'HashRef' =>
  via { File::ChangeNotify->instantiate_watcher( %{$_} ) };

has 'piper_log_file' => ( is => 'ro', lazy_build => 1 );
has 'piper_notify'   => ( is => 'ro', isa        => $cn_type, coerce => 1 );
has 'piper_pid'      => ( is => 'ro', init_arg   => undef );
has 'piper_verbose' => ( is => 'ro' );

after 'successful_start' => sub {
    my $self           = shift;
    my $piper_pid_file = dirname( $self->pid_file ) . "/piper.pid.$$";
    if ( -f $piper_pid_file ) {
        warn
          "piper pid file '$piper_pid_file' already exists - not creating another one";
        return;
    }
    my $watcher = Server::Control::Plugin::PiedPiper::Watcher->new(
        pid_file => $piper_pid_file,
        verbose  => $self->piper_verbose,
        log_file => $self->piper_log_file,
        notify   => $self->piper_notify,
        ctl      => $self
    );
    $watcher->start();
    for my $i ( 0 .. 5 ) {
        last if -f $piper_pid_file;
        usleep(250000);
    }
    if ( -f $piper_pid_file ) {
        $self->{piper_pid} = read_file($piper_pid_file);
    }
    else {
        die "piper pid file '$piper_pid_file' was not created";
    }
};

sub _build_piper_log_file {
    my ($self) = @_;

    return
      defined( $self->error_log )
      ? dirname( $self->error_log ) . "/piper.log"
      : die "no log file and could not determine from error log";
}

1;

__END__

=pod

=head1 NAME

Server::Control::Plugin::PiedPiper -- Refork server on file change

=head1 SYNOPSIS

    use Server::Control::Plugin::PiedPiper;

=head1 DESCRIPTION

Server::Control::Plugin::PiedPiper provides

=head1 AUTHOR

Jonathan Swartz

=head1 SEE ALSO

L<Some::Module>

=head1 COPYRIGHT & LICENSE

Copyright (C) 2007 Jonathan Swartz.

Server::Control::Plugin::PiedPiper is provided "as is" and without any express
or implied warranties, including, without limitation, the implied warranties of
merchantibility and fitness for a particular purpose.

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut
