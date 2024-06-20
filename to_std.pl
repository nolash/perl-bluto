#!/usr/bin/perl

use v5.10.1;
use warnings;
use strict;

# standard imports
use Getopt::Long qw/ :config auto_help /;
#use File::Temp qw/ tempdir /;
use File::Basename qw/ dirname /;
use File::Spec qw/ catfile /;
use File::Path qw/ make_path /;
use Cwd qw/ getcwd abs_path /;

# external imports
use Config::Simple;

# local imports
use lib dirname(abs_path($0));
use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto;
use Bluto::RSS;

sub croak {
	die(shift);
}

# TODO: export to perl modules

my %env = (
	src_dir => File::Spec->catfile(getcwd, '.bluto'),
	out_dir => File::Spec->catfile(getcwd, 'bluto_build'),
	feed_dir => undef,
	content_dir => getcwd,
	template_path => 'base.tt',
	engine => undef,
	readme => undef,
);
GetOptions(
	'd:s', \$env{src_dir},
	'o:s', \$env{out_dir},
	'f:s', \$env{feed_dir},
	'c:s', \$env{content_dir},
);
foreach my $k (keys %env ) {
	if (defined $env{$k}) {
		$env{$k} = abs_path($env{$k});
	}
}

if (!defined $env{feed_dir}) {
	$env{feed_dir} = $env{out_dir};
}

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

my $rss = Bluto::create_rss(\%env);
if (!defined $rss) {
	die("rss processing failed");
}

#my @change = $cfg->vars();
