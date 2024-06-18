#!/usr/bin/perl

use warnings;
use strict;

# standard imports
use Getopt::Long qw/ :config auto_help /;
use File::Temp qw/ tempdir /;
use File::Basename qw/ dirname /;
use File::Spec qw/ catfile /;
use Cwd qw/ getcwd abs_path /;
use Template;
use SemVer;

# external imports
use Config::Simple;

# local imports
use lib dirname(abs_path($0));
use Log::Term::Ansi qw/error info debug warn trace/;

sub croak {
	die(shift);
}

# TODO: export to perl modules
my %config;
my @m_tech;
my @m_author_maintainer = [undef, undef];
my @m_author_origin = [undef, undef];
my %m_main = (
	name => undef,
	slug => undef,
	version => undef,
	summary => undef,
	tech_main => undef,
	tech => \@m_tech,
	author_maintainer => \@m_author_maintainer,
	author_origin => \@m_author_origin,
);

my $ini_dir = File::Spec->catfile(getcwd, '.bluto');
my $out_dir = getcwd;
GetOptions(
	'd:s', \$ini_dir,
	'o:s', \$out_dir,
);
$ini_dir = abs_path($ini_dir);

info("using ini dir " . $ini_dir);

my $fn = File::Spec->catfile($ini_dir, 'bluto.ini');
debug("import from " . $fn);
my $cfg = new Config::Simple($fn);

$m_main{name} = $cfg->param('main.name');
$m_main{version} = $cfg->param('main.version');
$m_main{slug} = $cfg->param('main.slug');
$m_main{summary} = $cfg->param('main.summary');
$m_main{author_maintainer}[0] = $cfg->param('author:maintainer.name') . " <" . $cfg->param('author:maintainer.email') . ">";
$m_main{author_maintainer}[1] = $cfg->param('author:maintainer.pgp');

if (!defined $cfg->param('author:origin')) {
	$m_main{author_origin}[0] = $m_main{author_maintainer}[0];
	$m_main{author_origin}[1] = $m_main{author_maintainer}[1];
}


my @urls = $cfg->param('locate.url');
my @gits = $cfg->param('locate.git');
my @change = $cfg->vars();

my $have_version_match = undef;
foreach my $k ($cfg->vars()) {
	if ($k =~ /^changelog\.(.+)$/) {
		if ($m_main{version} eq $1) {
			if (defined $have_version_match) {
				croak('already have version defined for ' . $1);
			}
			debug('found version match in changelog for ' . $1);	

			$have_version_match = SemVer->new($1);
		}
	}
}

if (!defined $have_version_match) {
	croak("no changelog found for version " . $m_main{version});
}

my $targz = File::Spec->catfile($ini_dir, $m_main{slug} . '-' . $have_version_match . '.tar.gz');
if (! -f $targz ) {
	#croak("no package file found, looked for: " . $targz);
	debug("no package file found, looked for: " . $targz);
}

my $tt = Template->new({
	INCLUDE_PATH => '.',
	INTERPOLATE => 1,
	});
my $out;
$tt->process('base.tt', \%m_main, \$out) or croak($tt->error());
print($out);
