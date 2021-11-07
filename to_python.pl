#!/usr/bin/perl

use warnings;
use strict;

use Config::Simple;
use Getopt::Long qw/ :config auto_help /;
use File::Temp qw/ tempdir /;
use File::Spec qw/ catfile /;

Config::Simple->import_from('setup.env', \my %config);

my $d = tempdir( CLEANUP => 1 );
my $fn = File::Spec->catfile($d, 'config_py.ini');
my $fh;
open($fh, '>', $fn);
print $fh "[metadata]\n";
close($fh);

our %first_author = (
	name => undef,
	email => undef,
);
our $first_url;
for my $k (keys %config) {
	my @p = split(/:/, $k);
	if ($p[0] eq 'author' && ! defined $first_author{'name'}) {
		my @n = split(/\./, $p[1]);
		my $name =  $config{'author:' . $n[0] . '.name'};
		$first_author{'name'} = $name;
		my $email = $config{'author:' . $n[0] . '.email'};
		if (defined $email) {
			$first_author{'email'} = $email;
		}
	} elsif ($p[0] eq 'locate' && ! defined $first_url) {
		$first_url = $config{$k};
	}
}

my $py_cfg = new Config::Simple($fn);
$py_cfg->param('metadata.author_email', $first_author{email});
$py_cfg->param('metadata.author', $first_author{name});
$py_cfg->param('metadata.description', $config{'main.summary'});
$py_cfg->param('metadata.url', $first_url);
$py_cfg->param('metadata.version', $config{'main.version'});
$py_cfg->param('metadata.name', $config{'main.name'});

print $py_cfg->as_string()
