#!/usr/bin/perl

use v5.10.1;
use warnings;
use strict;
use constant { VERSION => '0.0.1' };

# standard imports
use Getopt::Long qw/ :config auto_help /;
use File::Temp qw/ tempdir /;
use File::Basename qw/ dirname /;
use File::Spec qw/ catfile /;
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

my $src_dir = File::Spec->catfile(getcwd, '.bluto');
my $out_dir = getcwd;
my $feed_dir = getcwd;
my $content_dir = getcwd;
GetOptions(
	'd:s', \$src_dir,
	'o:s', \$out_dir,
	'f:s', \$feed_dir,
	'c:s', \$content_dir,
);
$src_dir = abs_path($src_dir);

info("using ini dir " . $src_dir);

my $fn = File::Spec->catfile($src_dir, 'bluto.ini');
debug("import from " . $fn);
my $cfg = new Config::Simple($fn);

my $version = Bluto::from_config($cfg, $src_dir);

if (!defined $version) {
	die("config processing failed");
}

#my @change = $cfg->vars();
