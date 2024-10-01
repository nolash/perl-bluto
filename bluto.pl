#!/usr/bin/env perl

use v5.10.1;
use warnings;
use strict;

use File::Basename qw/ dirname /;
use Cwd qw/ getcwd abs_path /;
use lib (dirname(abs_path($0)));

use Bluto::Cmd;

#Bluto::Cmd::register_param("version", undef, "version", undef);
Bluto::Cmd::register_param("name", undef, "name", undef);
Bluto::Cmd::register_param("summary", undef, "summary", undef);
my $usr = $ENV{LOGNAME} || $ENV{USER} || getpwuid($<);
Bluto::Cmd::register_param("maintainer", $usr, undef, undef);

Bluto::Cmd::process_param();

#my $v = Bluto::Cmd::get_param("version");
#if (!defined $v) {
#	Bluto::Cmd::croak($v);
#}

my $name = Bluto::Cmd::get_param('name');
my $slug;
if (defined $name) {
	my $slug = lc();
	$slug =~ y/ /_/;
	$slug =~ s/[^a-zA-Z0-9_]//g;
}

my $yc = {
	name => $name,
	slug => $slug,
	summary => Bluto::Cmd::get_param('summary'),
	license => "",
	copyright => "",
	tech => "",
	vcs => {
		tag_prefix => "v",
	},
	sign => {
		rsa => "",
		ed22519 => "",
		secp256k1 => "",
	},
	fund => {
		btc => "",
		eth => "",
		monero => "",
	},
	locate => {
		www => [],
		rel => [],
		vcs => [],
		tgzbase => [],
	},
	author => {
		name => "",
		email => "",
		pgp => "",
	},
	maintainer => {
		name => Bluto::Cmd::get_param('maintainer'),
		email => "",
		pgp => "",
	},
};

my $yo = YAML::Tiny->new($yc);
#my $fn = File::Spec->catfile($env{src_dir}, 'bluto.yml');
my $fn = Bluto::Cmd::base_config_path();
$yo->write($fn);