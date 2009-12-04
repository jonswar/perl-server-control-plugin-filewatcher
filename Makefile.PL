use inc::Module::Install;

name 'Server-Control-Plugin-FileWatcher';
abstract 'Take server action on file change';
all_from 'lib/Server/Control/Plugin/FileWatcher.pm';
author 'Jonathan Swartz <swartz@pobox.com>';

perl_version '5.006';

build_requires 'Test::Class' => 0;
build_requires 'Test::Most'  => 0;

requires 'Log::Any::Adapter::Dispatch' => '0.05';
requires 'Proc::Daemon' => '0.03';
requires 'Server::Control' => '0.10';

license 'perl';

auto_install;

WriteAll;
