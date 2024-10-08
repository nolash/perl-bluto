#!/usr/bin/perl

use v5.10.1;
use warnings;
use strict;

# standard imports
use Getopt::Long qw/ :config auto_help /;
#use File::Temp qw/ tempdir /;
use File::Basename qw/ dirname /;
use File::Spec;
use Cwd qw/ getcwd abs_path /;
use lib (dirname(abs_path($0)));

# external imports
use Config::Simple;

# bundled external imports
use SemVer;

# local imports
use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto;
use Bluto::RSS;

sub croak {
	die(shift);
}

sub help() {
	print("$0\n\nwould have shown help...\n");
	exit 0;
}

# TODO: export to perl modules

my $force_version = undef;
my $loglevel = 0;
my $force_help = 0;
my %env = (
	src_dir => File::Spec->catfile(getcwd, '.bluto'),
	out_dir => File::Spec->catfile(getcwd, 'bluto_build'),
	feed_dir => undef,
	content_dir => getcwd,
	template_path => undef,
	engine => undef,
	readme => undef,
	version => undef,
	loglevel => undef,
);
GetOptions(
	'd:s', \$env{src_dir},
	'o:s', \$env{out_dir},
	'f:s', \$env{feed_dir},
	'c:s', \$env{content_dir},
	'v+', \$loglevel,
	'h+', \$force_help,
	'help+', \$force_help,
	'version=s', \$force_version,
);

if ($force_help > 0) {
	help;
}

foreach my $k (keys %env ) {
	if (defined $env{$k}) {
		$env{$k} = abs_path($env{$k});
	}
}

if (!defined $env{feed_dir}) {
	$env{feed_dir} = $env{out_dir};
}

if (defined $force_version) {
	$env{version} = SemVer->new($force_version);
}

$env{loglevel} = $loglevel;

$env{engine} = 'bluto v' . SemVer->new(Bluto::VERSION). " (perl $^V)";
foreach my $k (keys %env ) {
	if (defined $env{$k}) {
		debug('environment "' . $k . '":  ' . $env{$k});
	}
}

if (Bluto::check_sanity(\%env)) {
	croak('sanity check fail');
}

my $fn = File::Spec->catfile($env{src_dir}, 'bluto.ini');
debug("import from " . $fn);
my $cfg = new Config::Simple($fn);

my $version = Bluto::from_config($cfg, \%env);
if (!defined $version) {
	die("config processing failed");
}

my $announce = Bluto::create_announce(\%env);
if (!defined $announce) {
	die("announce processing failed");
}

my $rss = Bluto::create_rss(\%env);
if (!defined $rss) {
	die("rss processing failed");
}

#my @change = $cfg->vars();
