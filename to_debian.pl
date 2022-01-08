#!/usr/bin/perl

use warnings;
use strict;

# standard imports
use Getopt::Long qw/:config auto_help/;
use File::Spec qw/ catfile /;
use Cwd qw/ getcwd abs_path /;

# external imports
use Config::Simple;

my $deb_standards_version = '3.9.5';
my $deb_priority = 'optional';
my $deb_arch = 'any';
my $deb_section = 'development';

my $ini_dir = File::Spec->catfile(getcwd, '.bluto');
my $out_dir = File::Spec->catfile(getcwd, 'debian');
GetOptions(
	'd:s', \$ini_dir,
	'o:s', \$out_dir,
	'standards-version:s' => \$deb_standards_version,
	'priority:s' => \$deb_priority,
	'arch:s' => \$deb_arch,
	'section=s' => \$deb_section,
);
$ini_dir = abs_path($ini_dir);

print STDERR "using ini dir " . $ini_dir . "\n";

my $fn = File::Spec->catfile($ini_dir, 'bluto.ini');
Config::Simple->import_from($fn, \my %config);

$fn = File::Spec->catfile($ini_dir, 'bluto.deb.ini');
Config::Simple->import_from($fn, \my %config_deb);


our $deb_first_author;
our $deb_first_url;
our $deb_first_license;
for my $k (keys %config) {
	my @p = split(/:/, $k);
	print STDERR "processing key " . $k . " " . $p[0] . "\n";
	if ($p[0] eq 'author' && ! defined $deb_first_author) {
		my @n = split(/\./, $p[1]);
		my $name =  $config{'author:' . $n[0] . '.name'};
		$deb_first_author = $name;
		my $email = $config{'author:' . $n[0] . '.email'};
		if (defined $email) {
			$deb_first_author .= ' <' . $email . '>';
		}
	} elsif ($p[0] eq 'locate' && ! defined $deb_first_url) {
		$deb_first_url = $config{$k};
	}

	@p = split(/\./, $p[0], 2);
	if ($p[0] eq 'license' && ! defined $deb_first_license) {
		$deb_first_license = $p[1] . '-' . $config{$k};
	}
}

my %deb_depends = (
	'exec' => [],
	'build' => [],
	'install' => [],
);
for my $k (keys %config_deb) {
	my @p = split(/\./, $k, 2);
	if (substr($p[0], 0, 7) eq 'dep:deb') {
		my @m = split(/-/, $p[0]);
		my $dep = $p[1];
		if ($config_deb{$k} ne '0') {
			$dep .= ' (' . $config_deb{$k}. ')';
		}
		push(@{$deb_depends{$m[1]}}, $dep);
	}
}

my $fh;
$fn = File::Spec->catfile($out_dir, 'control');
open($fh, '>', $fn);

print $fh "Source: " . $config{'main.name'} . "\n";
print $fh "Section: " . $deb_section . "\n";
print $fh "Priority: " . $deb_priority . "\n";
print $fh "Maintainer: " . $deb_first_author . "\n";
print $fh "Standards-Version: " . $deb_standards_version . "\n";
print $fh "Package: " . $config{'main.name'} . "\n";
print $fh "Architecture: " . $deb_arch . "\n";
my $v = join(', ', @{$deb_depends{'build'}});
if ($v ne '') {
	print $fh "Build-Depends: " . $v . "\n";
}
print $fh "\n";

$v = join(', ', @{$deb_depends{'install'}});
if ($v ne '') {
	print $fh "Pre-Depends: " .  $v. "\n";
}
$v = join(', ', @{$deb_depends{'exec'}});
if ($v ne '') {
	print $fh "Depends: " .  $v. "\n";
}
print $fh "Description: " . $config{'main.summary'} . "\n";
close($fh);


$fn = File::Spec->catfile($out_dir, 'compat');
open($fh, '>', $fn);
print $fh $config_deb{'main:deb.engine'};
close($fh);

$fn = File::Spec->catfile($out_dir, 'copyright');
open($fh, '>', $fn);
print $fh "Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/\n";
print $fh "Upstream-Name: " . $config{'main.name'}. "\n";
print $fh "Source: " . $deb_first_url . "\n";
print $fh "\n";
print $fh "Files: *\n";

my @time = localtime();
my $year = $time[5] + 1900;
print $fh "Copyright: Copyright " . $year . " " . $deb_first_author . "\n";
print $fh "License: " . $deb_first_license . "\n";
close($fh);

$fn = File::Spec->catfile($out_dir, 'changelog');
if (! -f $fn) {
	open($fh, '>', $fn);
	print $fh $config{'main.name'} . " (" . $config{'main.version'} . ") UNRELEASED; urgency: low\n\n";
	print $fh "  * Automatic commit message from bluto\n\n";
	print $fh " -- " . $first_author . "  " . 
	close($fh);
