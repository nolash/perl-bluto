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
use Template;
use SemVer;
use XML::RSS;
use DateTime;

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
my @m_url;
my @m_vcs;
my @m_src;
my @m_author_maintainer = [undef, undef];
my @m_author_origin = [undef, undef];
my %m_main = (
	name => undef,
	slug => undef,
	version => undef,
	summary => undef,
	license => undef,
	changelog => '',
	time => undef,
	tech_main => undef,
	tech => \@m_tech,
	vcs => \@m_vcs,
	url => \@m_url,
	src => \@m_src,
	author_maintainer => \@m_author_maintainer,
	author_origin => \@m_author_origin,
);

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

my $version;
if (defined $cfg->{version}) {
	$version = $cfg->{version};
} else {
	$fn = File::Spec->catfile($src_dir, 'VERSION');
	open(my $f, "<$fn") or die("no version file found");
	$version = <$f>;
	close($f);
	$version = SemVer->new($version);
}
info('using version ' . $version);

$m_main{name} = $cfg->param('main.name');
#$m_main{version} = $cfg->param('main.version');
$m_main{version} = $version;
$m_main{slug} = $cfg->param('main.slug');
$m_main{summary} = $cfg->param('main.summary');
$m_main{license} = $cfg->param('main.license');
$m_main{author_maintainer}[0] = $cfg->param('author:maintainer.name') . " <" . $cfg->param('author:maintainer.email') . ">";
$m_main{author_maintainer}[1] = $cfg->param('author:maintainer.pgp');

my $feed_file = File::Spec->catfile( $feed_dir, $m_main{slug} ) . ".rss";

if (!defined $cfg->param('author:origin')) {
	$m_main{author_origin}[0] = $m_main{author_maintainer}[0];
	$m_main{author_origin}[1] = $m_main{author_maintainer}[1];
}

foreach my $v ( $cfg->param('locate.url') ) {
	warn('not checking url formatting for ' . $v);
	push(@m_url, $v);
}

foreach my $v ( $cfg->param('locate.vcs') ) {
	warn('not checking git formatting for ' . $v);
	push(@m_vcs, $v);
}

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
my $targz = $m_main{slug} . '-' . $have_version_match . '.tar.gz';
my $targz_local = File::Spec->catfile($src_dir, $targz);
if (! -f $targz_local ) {
	#croak("no package file found, looked for: " . $targz);
	debug("no package file found, looked for: " . $targz);
}
my @targz_stat = stat ( $targz_local );
$m_main{time} = DateTime->from_epoch( epoch => $targz_stat[9] )->stringify();
foreach my $v ( $cfg->param('locate.tgzbase') ) {
	warn('not checking targz base formatting for ' . $v);
	my $src = $m_main{slug} . '/' . $targz;
	push(@m_src, $v . '/' . $src);
}

my @change = $cfg->vars();


# process changelog entry
my $body = '';
if (!defined $have_version_match) {
	croak("no changelog found for version " . $m_main{version});
} else {
	# TODO: else should look for targz filename dot txt and include literal
	if ($cfg->param('changelog.' . $have_version_match) =~ '^sha256:(.*)$' ) {
		my $fp = File::Spec->catfile ( $content_dir, $1 );
		debug('resolve sha256 content ' . $1 . ' for ' . $have_version_match . ' from ' . $fp);
		open(my $f, "<$fp") or die ('cannot open content read from: ' . $fp);
		while (<$f>) {
			$m_main{changelog} .= $_;
		}
	}
}


my $tt = Template->new({
	INCLUDE_PATH => '.',
	INTERPOLATE => 1,
	});
my $out;
$tt->process('base.tt', \%m_main, \$out) or croak($tt->error());


my $rss_title = $m_main{slug} . ' ' . $m_main{version};
my $rss;
$rss = XML::RSS->new;
if ( -f $feed_file ) {
	info('found existing feed file ' . $feed_file);
	$rss->parsefile( $feed_file );
	foreach my $v ( @{$rss->{items}} ) {
		debug('rss contains: ' . $v->{title});
		if ($v->{title} eq $rss_title) {
			die('already have rss entry for ' . $rss_title);
		}
	}
} else {
	info('starting new feed file ' . $feed_file);
	$rss = XML::RSS->new(version => '1.0');
	$rss->channel (
		title => $m_main{name},
		link => $m_main{git_upstream},
		description => $m_main{summary},
		dc => {
			date => DateTime->now()->stringify(),
			creator => $m_main{author_maintainer},
			publisher => "$0 " . SemVer->new(VERSION). " (perl $^V)",
		},
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
foreach my $item ( $rss->{items}) {
	if ( defined $item->[0] && $item->[0]{title} eq $rss_title ) {
		die('already have published record for ' . $rss_title);
	}
}

$rss->add_item (
	title => $rss_title,
	link => $targz,
	description => $out,
	dc => {
		date => $m_main{time},
	},
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
