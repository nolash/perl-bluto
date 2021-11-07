#!/usr/bin/perl

use warnings;
use strict;

use Config::Simple;
use Getopt::Long qw/:config auto_help/;

my $deb_standards_version = '3.9.5';
my $deb_priority = 'optional';
my $deb_arch = 'any';

GetOptions(
	'standards-version:s' => \$deb_standards_version,
	'priority:s' => \$deb_priority,
	'arch:s' => \$deb_arch,
);


Config::Simple->import_from('setup.env', \my %config);
Config::Simple->import_from('setup.deb.env', \my %config_deb);


our $first_author;

for my $k (keys %config) {
	my @p = split(/:/, $k);
	print "processing key " . $k . " " . $p[0] . "\n";
	if ($p[0] eq 'author' && ! defined $first_author) {
		my @n = split(/\./, $p[1]);
		my $name =  $config{'author:' . $n[0] . '.name'};
		$first_author = $name;
		my $email = $config{'author:' . $n[0] . '.email'};
		if (defined $email) {
			$first_author .= ' <' . $email . '>';
		}
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


print "Source: " . $config{'main.name'} . "\n";
print "Section: " . $config{'tech.name'} . "\n";
print "Priority: " . $deb_priority . "\n";
print "Maintainer: " . $first_author . "\n";
print "Standards-Version: " . $deb_standards_version . "\n";
print "Build-Depends: " . join(', ', @{$deb_depends{'build'}}) . "\n";
print "\n";
print "Package: " . $config{'main.name'} . "\n";
print "Architecture: " . $deb_arch . "\n";
print "Pre-Depends: " . join(', ', @{$deb_depends{'install'}}) . "\n";
print "Depends: " . join(', ', @{$deb_depends{'exec'}}) . "\n";
print "Description: " . $config{'main.summary'} . "\n";
