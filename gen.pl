#!/usr/bin/perl

use v5.10.1;
use warnings;
use strict;

use Getopt::Long qw/ :config auto_help /;
use File::Basename qw/ dirname /;
use File::Spec;
use File::Copy;
use Cwd qw/ getcwd abs_path /;
use lib (dirname(abs_path($0)));
use Digest::SHA;

use SemVer;
use Log::Term::Ansi qw/debug/;
use YAML::Tiny;

# TODO: export to perl modules


sub croak {
	die(shift);
}

sub help() {
	print("$0\n\nwould have shown help...\n");
	exit 0;
}

my $force_version = undef;
my $loglevel = 0;
my $force_help = 0;
my %env = (
	src_dir => File::Spec->catfile(getcwd, '.bluto'),
	changelog_file => undef,
	version => undef,
	loglevel => undef,
);
GetOptions(
	'd:s', \$env{src_dir},
	'f:s', \$env{changelog_file},
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

if (defined $force_version) {
	$env{version} = SemVer->new($force_version);
}

my $fn = File::Spec->catfile($env{src_dir}, 'bluto.yml');
my $yi = YAML::Tiny->read($fn);

my @contributors;
my $yd = $yi->[0];
my $yv = {
	changelog => 'sha256:' . process_changelog(\%env, 1),
	author => $yd->{author}->{name},
	maintainer => $yd->{maintainer}->{name},
	contributors => \@contributors,
};
my $yo = YAML::Tiny->new($yv);
$fn = File::Spec->catfile($env{src_dir}, $env{version} . '.yml');
$yo->write($fn);


sub process_changelog {
	my $env = shift;
	my $copy = shift;

	my $h = Digest::SHA->new('sha256');
	$h->addfile($env->{changelog_file});
	my $z = $h->hexdigest;
	debug('calculated sha256 ' . $z . ' for changelog ' . $env->{changelog_file});
	if ($copy) {
		my $fp = File::Spec->catfile($env->{src_dir}, 'CHANGELOG.' . $env->{version});
		copy($env->{changelog_file}, $fp);
	}
	return $z;
}
