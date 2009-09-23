#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'Server::Control::Plugin::PiedPiper' );
}

diag( "Testing Server::Control::Plugin::PiedPiper $Server::Control::Plugin::PiedPiper::VERSION, Perl $], $^X" );
