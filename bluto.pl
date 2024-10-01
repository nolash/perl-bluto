#!/usr/bin/env perl

use v5.10.1;
use warnings;
use strict;

use File::Basename qw/ dirname /;
use Cwd qw/ getcwd abs_path /;
use lib (dirname(abs_path($0)));

use Bluto::Cmd;

Bluto::Cmd::register_param("version", undef, "version", undef);
Bluto::Cmd::process_param();

my $v = Bluto::Cmd::get_param("version");
if (!defined $v) {
	Bluto::Cmd::croak($v);
}
