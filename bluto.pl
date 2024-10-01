#!/usr/bin/env perl

use v5.10.1;
use warnings;
use strict;

use File::Basename qw/ dirname /;
use Cwd qw/ getcwd abs_path /;
use lib (dirname(abs_path($0)));

use Bluto::Cmd;

Bluto::Cmd::register_param("version", undef, "version", undef);
Bluto::Cmd::register_param("changelog_file", undef, undef, "f");

Bluto::Cmd::process_param();

my $version = Bluto::Cmd::get_version();
if (!defined $version) {
	Bluto::Cmd::croak("version missing");
}


my @contributors;
my $yd = Bluto::Cmd::base_config();
my $yv = {
	changelog => 'sha256:' . Bluto::Cmd::process_changelog(1),
	author => $yd->{author}->{name},
	maintainer => $yd->{maintainer}->{name},
	contributors => \@contributors,
};

my $yo = YAML::Tiny->new($yv);
my $fn = Bluto::Cmd::release_config_path();
$yo->write($fn);
