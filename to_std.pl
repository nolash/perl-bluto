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

my %env = (
	src_dir => File::Spec->catfile(getcwd, '.bluto'),
	out_dir => getcwd,
	feed_dir => getcwd,
	content_dir => getcwd,
	template_path => 'base.tt',
);
#my $src_dir = 
#my $out_dir = getcwd;
#my $feed_dir = getcwd;
#my $content_dir = getcwd;
GetOptions(
	'd:s', \$env{src_dir},
	'o:s', \$env{out_dir},
	'f:s', \$env{feed_dir},
	'c:s', \$env{content_dir},
);
foreach my $k (keys %env ) {
	$env{$k} = abs_path($env{$k});
	debug('environment "' . $k . '":  ' . $env{$k});
}

my $fn = File::Spec->catfile($env{src_dir}, 'bluto.ini');
debug("import from " . $fn);
my $cfg = new Config::Simple($fn);

my $version = Bluto::from_config($cfg, \%env);

if (!defined $version) {
	die("config processing failed");
}

my $announcement = Bluto::get_announcement(\%env);

print($announcement);

#my @change = $cfg->vars();
