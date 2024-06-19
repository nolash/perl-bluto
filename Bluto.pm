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
my @m_author_maintainer = [undef, undef, undef];
my @m_author_origin = [undef, undef, undef];
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

sub _set_single {
	my $cfg = shift;
	my $cfg_k = shift;
	my $main_k = shift;
	my $need = shift;

	my $v = $cfg->param($cfg_k);
	if (ref($v) eq 'ARRAY') {
		if ($#v < 0) {
			debug('empty value not set: ' . $cfg_k);
			$v = undef;
		}
	}

	if ($need && !defined $v) {
		error('required config key not set: ' . $cfg_k);
		return 1;
	}

	$m_main{$main_k} = $v;

	return 0;
}

sub _set_author {
	my $cfg = shift;
	my $k = shift;
	my $need = shift;
	my $name;
	my $email;
	my $pgp;

	my $cfg_k = 'author:' . $k;
	my $v = $cfg->param($cfg_k . '.name');
	# TODO if if if...
	if (defined $v) {
		$name = $cfg->param($cfg_k . '.name');
		if (ref($name) eq 'ARRAY') {
			$v = undef;
		} else {
			$email = $cfg->param($cfg_k . '.email');
			if (ref($email) eq 'ARRAY') {
				$email = undef;
			}
			$pgp = $cfg->param($cfg_k . '.pgp');
			if (ref($pgp) eq 'ARRAY') {
				$pgp = undef;
			}
		}
	}

	if ($need && !defined $v) {
		error('required author data not set: ' . $cfg_k);
		return 1;
	}

	$m_main{'author_' . $k}[0] = $name;
	if (defined $email) {
		$m_main{'author_' . $k}[1] = $name . ' <' . $email . '>';
	}
	$m_main{'author_' . $k}[2] = $pgp;

	return 0;
}

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

	$m_main{version} = $version;
	my $r = 0;
	$r += _set_single($cfg, 'main.name', 'name', 1);
	$r += _set_single($cfg, 'main.slug', 'slug', 1);
	$r += _set_single($cfg, 'main.summary', 'summary', 1);
	$r += _set_single($cfg, 'main.license', 'license', 1);
	$r += _set_single($cfg, 'main.uri', 'uri', 1);
	$r += _set_author($cfg, 'maintainer', 1);
	if ($r) {
		error('invalid configuration');
		return undef;
	}


#	$m_main{author_maintainer}[0] = $cfg->param('author:maintainer.name');
#	$m_main{author_maintainer}[1] = $m_main{author_maintainer}[0] . " <" . $cfg->param('author:maintainer.email') . ">";
#	$m_main{author_maintainer}[2] = $cfg->param('author:maintainer.pgp');
#
	my $feed_file = File::Spec->catfile( $feed_dir, $m_main{slug} ) . ".rss";

#	if (!defined $cfg->param('author:origin')) {
#		$m_main{author_origin}[0] = $m_main{author_maintainer}[0];
#		$m_main{author_origin}[1] = $m_main{author_maintainer}[1];
#		$m_main{author_origin}[2] = $m_main{author_maintainer}[2];
#	}

	if (defined $cfg->param('vcs.tag_prefix')) {
		$m_main{tag_prefix} = $cfg->param('vcs.tag_prefix');

	}

	foreach my $v ( $cfg->param('locate.www') ) {
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

	my $targz = Bluto::Archive::create($m_main{slug}, $m_main{version}, $m_main{author_maintainer}[2], $m_main{tag_prefix}, $env->{src_dir}, 0);
	if (!defined $targz) {
		error('failed to generate archive');
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
		debug('found sha256 changelog entry ' . $1 . ' for ' . $have_version_match);
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

	for $k (keys %m_main) {
		debug('release data: ' . $k . ': ' . $m_main{$k});
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
