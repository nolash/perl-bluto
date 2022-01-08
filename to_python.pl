#!/usr/bin/perl

use warnings;
use strict;

# standard imports
use Getopt::Long qw/ :config auto_help /;
use File::Temp qw/ tempdir /;
use File::Spec qw/ catfile /;
use File::Basename qw/ dirname /;
use Cwd qw/ getcwd abs_path /;

# external imports
use Config::Simple;

# local imports
use lib dirname(abs_path($0));
use Log::Term::Ansi qw/error info debug warn trace/;

my $ini_dir = File::Spec->catfile(getcwd, '.bluto');
GetOptions(
	'd:s', \$ini_dir,
);
$ini_dir = abs_path($ini_dir);

info("using ini dir " . $ini_dir . "\n");

my $fn = File::Spec->catfile($ini_dir, 'bluto.ini');
Config::Simple->import_from($fn, \my %config);

$fn = File::Spec->catfile($ini_dir, 'bluto.py.ini');
Config::Simple->import_from($fn, \my %config_py);

my $r;

my $d = tempdir( CLEANUP => 1 );
$fn = File::Spec->catfile($d, 'config_py.ini');
my $fh;
open($fh, '>', $fn);
print $fh "[metadata]\n";
close($fh);

our %py_first_author = (
	name => undef,
	email => undef,
);

our $py_first_url;
our $py_first_license;
for my $k (keys %config) {
	my @p = split(/:/, $k, 2);
	if ($p[0] eq 'author' && ! defined $py_first_author{'name'}) {
		my @n = split(/\./, $p[1]);
		my $name =  $config{'author:' . $n[0] . '.name'};
		$py_first_author{'name'} = $name;
		my $email = $config{'author:' . $n[0] . '.email'};
		if (defined $email) {
			$py_first_author{'email'} = $email;
		}
	} elsif ($p[0] eq 'locate' && ! defined $py_first_url) {
		$py_first_url = $config{$k};
	}

	@p = split(/\./, $p[0], 2);
	if ($p[0] eq 'license' && ! defined $py_first_license) {
		$py_first_license = $p[1] . $config{$k};
	}
}

our @py_tags;
our @py_classifiers;
my $fh_tag;
$r = open($fh_tag, '<', 'bluto.tag');
if ($r) {
	while (<$fh_tag>) {
		my $v = $_;
		chomp($v);
		my @p = split(/ :: /, $v);
		if ($#p > 0) {
			push(@py_classifiers, $v);
		} else {
			push(@py_tags, $v);
		}
	}
}

my $py_cfg = new Config::Simple($fn);
$py_cfg->param('metadata.author_email', $py_first_author{email});
$py_cfg->param('metadata.author', $py_first_author{name});
$py_cfg->param('metadata.description', $config{'main.summary'});
$py_cfg->param('metadata.url', $py_first_url);
$py_cfg->param('metadata.version', $config{'main.version'});
$py_cfg->param('metadata.name', $config{'main.name'});
$py_cfg->param('metadata.license', $py_first_license);
print $py_cfg->as_string();

if ($#py_tags > -1) {
	print "keywords =\n";
	for my $v (@py_tags) {
		print "\t" . $v . "\n";
	}
}

if ($#py_classifiers > -1) {
	print "classifiers =\n";
	for my $v (@py_classifiers) {
		print "\t" . $v . "\n";
	}
}
