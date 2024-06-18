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
use XML::RSS;

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
	vcs_upstream => undef,
	author_maintainer => \@m_author_maintainer,
	author_origin => \@m_author_origin,
);

my $ini_dir = File::Spec->catfile(getcwd, '.bluto');
my $out_dir = getcwd;
my $feed_dir = getcwd;
GetOptions(
	'd:s', \$ini_dir,
	'o:s', \$out_dir,
	'f:s', \$feed_dir,
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

my $feed_file = File::Spec->catfile( $feed_dir, $m_main{slug} ) . ".rss";

if (!defined $cfg->param('author:origin')) {
	$m_main{author_origin}[0] = $m_main{author_maintainer}[0];
	$m_main{author_origin}[1] = $m_main{author_maintainer}[1];
}

my @urls = $cfg->param('locate.url');
my @gits = $cfg->param('locate.git');
if ($#gits < 0) {
	die('no vcs found');
}
$m_main{git_upstream} = $gits[0];
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

my $targz = $m_main{slug} . '-' . $have_version_match . '.tar.gz';
my $targz_local = File::Spec->catfile($ini_dir, $targz);
if (! -f $targz_local ) {
	#croak("no package file found, looked for: " . $targz);
	debug("no package file found, looked for: " . $targz);
}

my $tt = Template->new({
	INCLUDE_PATH => '.',
	INTERPOLATE => 1,
	});
my $out;
$tt->process('base.tt', \%m_main, \$out) or croak($tt->error());

my $rss;

$rss = XML::RSS->new;
if ( -f $feed_file ) {
	info('found existing feed file ' . $feed_file);
	$rss->parsefile( $feed_file );
} else {
	my $rss = XML::RSS->new(version => '1.0');
	$rss->channel (
		title => $m_main{name},
		link => $m_main{git_upstream},
		description => $m_main{summary},
	#	dc => {
	#		date       => '2000-08-23T07:00+00:00',
	#		subject    => "Linux Software",
	#		creator    => 'scoop@freshmeat.net',
	#		publisher  => 'scoop@freshmeat.net',
	#		rights     => 'Copyright 1999, Freshmeat.net',
	#		language   => 'en-us',
	#	},
	#	  taxo => [
	#	       'http://dmoz.org/Computers/Internet',
	#	            'http://dmoz.org/Computers/PC'
	#	               ]
	);
}

# check if we already have the title
my $rss_title = $m_main{slug} . ' ' . $m_main{version};
foreach my $item ( $rss->{items}) {
	if ( defined $item->[0] && $item->[0]{title} eq $rss_title ) {
		die('already have published record for ' . $rss_title);
	}
}

$rss->add_item (
	title => $rss_title,
	link => $targz,
	description => $out,
#  dc => {
	#       subject  => "X11/Utilities",
	#            creator  => "David Allen (s2mdalle at titan.vcu.edu)",
	#               },
	#                  taxo => [
	#                       'http://dmoz.org/Computers/Internet',
	#                            'http://dmoz.org/Computers/PC'
	#                               ]
);

$rss->save($feed_file);
