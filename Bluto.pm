package Bluto;

use File::Basename qw/ basename /;
use SemVer;

use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto::Archive;

use constant { VCS_TAG_PREFIX => 'v' };

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
	tag_prefix => VCS_TAG_PREFIX,
	changelog => undef,
	time => undef,
	tech_main => undef,
	tech => \@m_tech,
	vcs => \@m_vcs,
	url => \@m_url,
	src => \@m_src,
	author_maintainer => \@m_author_maintainer,
	author_origin => \@m_author_origin,
);
my $have_version_match = undef;

sub from_config {
	my $cfg = shift;
	my $env = shift;

	my $version;
	if (defined $cfg->{version}) {
		$version = $cfg->{version};
	} else {
		$fn = File::Spec->catfile($env->{src_dir}, 'VERSION');
		open(my $f, "<$fn") or error('no version file found: ' . $fn) && return undef;
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
	$m_main{url} = $cfg->param('main.url');
	$m_main{author_maintainer}[0] = $cfg->param('author:maintainer.name') . " <" . $cfg->param('author:maintainer.email') . ">";
	$m_main{author_maintainer}[1] = $cfg->param('author:maintainer.pgp');

	my $feed_file = File::Spec->catfile( $feed_dir, $m_main{slug} ) . ".rss";

	if (!defined $cfg->param('author:origin')) {
		$m_main{author_origin}[0] = $m_main{author_maintainer}[0];
		$m_main{author_origin}[1] = $m_main{author_maintainer}[1];
	}

	if (defined $cfg->param('vcs.tag_prefix')) {
		$m_main{tag_prefix} = $cfg->param('vcs.tag_prefix');

	}

	foreach my $v ( $cfg->param('locate.url') ) {
		warn('not checking url formatting for ' . $v);
		push(@m_url, $v);
	}

	foreach my $v ( $cfg->param('locate.vcs') ) {
		warn('not checking git formatting for ' . $v);
		push(@m_vcs, $v);
	}

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
		error("no changelog found for version " . $m_main{version});
		return undef;
	} 

	my $targz = Bluto::Archive::create($m_main{slug}, $m_main{version}, $m_main{tag_prefix}, $env->{src_dir});
	if (!defined $targz) {
		return undef;
	}
	my @targz_stat = stat ( $targz );
	$m_main{time} = DateTime->from_epoch( epoch => $targz_stat[9] )->stringify();
	foreach my $v ( $cfg->param('locate.tgzbase') ) {
		warn('not checking targz base formatting for ' . $v);
		my $src = $m_main{slug} . '/' . basename($targz);
		push(@m_src, $v . '/' . $src);
	}

	# process changelog entry
	my $body = '';
	my $version_src = $cfg->param('changelog.' . $have_version_match);
	my @changelog_candidates;

	if ($version_src =~ '^sha256:(.*)$' ) {
		push(@changelog_candidates, $1);
		debug('found sha256 changelog entry ' . $1 . ' for ' . $have_version_match . ' from ' . $fp);
	} else {
		push(@changelog_candidates, $version_src);
	}

	push(@changelog_candidates, "CHANGELOG." . $have_version_match);
	push(@changelog_candidates, "CHANGELOG/" . $have_version_match);
	push(@changelog_candidates, "CHANGELOG/CHANGELOG." . $have_version_match);

	# TODO: if have sha256, check against the contents
	for my $fn (@changelog_candidates) {
		my $fp = File::Spec->catfile ( $env->{content_dir}, $fn );
		if (open(my $f, "<$fp")) {
			$m_main{changelog} = '';
			while (<$f>) {
				$m_main{changelog} .= $_;
			}
			close($f);
			info('read changelog info from ' . $fp);
			last;
		} else {
		      debug('changelog candidate ' . $fp . ' not available: ' . $!);
		}
	}
	
	if (!defined $m_main{changelog}) {
		error('changelog content empty after exhausting all options');
	}

	return $have_version_match;
}

sub get_announcement {
	my $env = shift;

	my $tt = Template->new({
		INCLUDE_PATH => '.',
		INTERPOLATE => 1,
		ABSOLUTE => 1,
		});
	my $out;
	$tt->process($env->{template_path}, \%m_main, \$out) or error('error processing template: '. $tt->error());
	return $out;
}

sub get_rss {
	my $env = shift;

	my $out = get_announcement($env);

	return Bluto::RSS::to_string(\%m_main, $env, $out);
}

1;
