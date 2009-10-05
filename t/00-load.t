#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Server::Control::Plugin::FileWatcher' );
}

diag( "Testing Server::Control::Plugin::FileWatcher $Server::Control::Plugin::FileWatcher::VERSION, Perl $], $^X" );
