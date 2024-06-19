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
my $have_version_match = undef;

sub from_config {
	my $cfg = shift;
	my $src_dir = shift;
	my $version;
	if (defined $cfg->{version}) {
		$version = $cfg->{version};
	} else {
		$fn = File::Spec->catfile($src_dir, 'VERSION');
		open(my $f, "<$fn") or error("no version file found") && return undef;
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

	
	my $targz = Bluto::Archive::create($m_main{slug}, $m_main{version}, $m_main{tag_prefix}, $src_dir);
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
	if (!defined $have_version_match) {
		error("no changelog found for version " . $m_main{version});
		return undef;
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
	

	return $have_version_match;
}

sub get_announcement() {
	my $tt = Template->new({
		INCLUDE_PATH => '.',
		INTERPOLATE => 1,
		});
	my $out;
	$tt->process('base.tt', \%m_main, \$out) or croak($tt->error());
}

1;
