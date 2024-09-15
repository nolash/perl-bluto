package Bluto;

use File::Basename qw/ basename /;
use SemVer;

use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto::Archive;
use Bluto::Announce;
use Bluto::Tree;
use File::Path qw / make_path /;

use constant { VCS_TAG_PREFIX => 'v' };
use constant { VERSION => '0.0.1' };

our %config;
our $have_version_match = undef;
our @m_tech;
our @m_url;
our @m_vcs;
our @m_src;
our @m_author_maintainer = [undef, undef, undef];
our @m_author_origin = [undef, undef, undef];
our %m_main = (
	name => undef,
	slug => undef,
	version => undef,
	summary => undef,
	license => undef,
	copyright => undef,
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
	engine => undef,
);

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

sub _check_ini {
	my $env = shift;

	my $fp = File::Spec->catfile($env->{src_dir}, 'bluto.ini');
	if ( ! -f $fp ) {
		error('ini file not found: ' . $fp);
		return 1;
	}
	debug('using ini file: ' . $fp);
	return 0;
}

sub _check_readme {
	my $env = shift;
	my $f;
	my $fp;

	for my $fn (('README', 'README.txt', 'README.adoc', 'README.rst', 'README.md')) {
		$fp = File::Spec->catfile($env->{content_dir}, $fn);
		if ( -f $fp ) {
			debug('using readme file: ' . $fp);
			$env{readme} = $fp;
			return 0;
		}
	}

	warn('no readme file found');
	return 1;
}

sub _check_version {
	my $env = shift;
	my $f;
	my $fp;

	$fp = File::Spec->catfile($env->{content_dir}, 'VERSION');
	if ($env->{version}) {
		info('writing new explicit version ' . $env->{version} . ' to file: ' . $fp);
		open($f, '>', $fp);
		print $f $env->{version};
		close($f);
	}
	if (! -f $fp ) {
		error('no version file');
		return 1;
	}
	debug('using version file: ' . $fp);
	return 0;
}

sub _prepare_out {
	my $release = shift;
	my $env = shift;

	return Bluto::Tree::prepare($release, $env);
}

sub check_sanity {
	my $env = shift;
	my $r = 0;

	$r += _check_readme($env);	
	$r += _check_ini($env);
	$r += _check_version($env);

	return $r;
}

sub from_config {
	my $cfg = shift;
	my $env = shift;

	my $version;
	if (defined $cfg->{version}) {
		$version = $cfg->{version};
	} else {
		$fn = File::Spec->catfile($env->{content_dir}, 'VERSION');
		open(my $f, '<', $fn) or error('no version file found: ' . $fn) && return undef;
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
	$r += _set_single($cfg, 'main.copyright', 'copyright', 1);
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

	$r = _prepare_out(\%m_main, $env);
	if ($r > 0) {
		error('output location preparations fail');
		return undef;	
	}

	#my $targz = Bluto::Archive::create($m_main{slug}, $m_main{version}, $m_main{author_maintainer}[2], $m_main{tag_prefix}, $env->{src_dir}, $env->{out_dir}, 0);
	my $targz = Bluto::Archive::create(\%m_main, $env, 0);
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
	
	if ($#m_src < 0) {
		error('no source bundle prefixes defined');
		return undef;
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
		my $fp = File::Spec->catfile ( $env->{src_dir}, $fn );
		if (open(my $f, '<', $fp)) {
			$m_main{changelog} = '';
			my $i = 0;
			while (!eof($f)) {
				my $v = readline($f);
				if ($v =~ /^[a-zA-Z0-9]/) {
					chomp($v);
					if ($i > 0) {
						$m_main{changelog} .= "\n";
					}
					$m_main{changelog} .= '* ' . $v;
				}
				$i++;
			}
			close($f);
			info('read changelog info from ' . $fp);
			last;
		} else {
		      debug('changelog candidate ' . $fp . ' not available: ' . $!);
		}
	}
	
	if (!defined $m_main{changelog} || ref($m_main{changelog} eq 'ARRAY')) {
		error('changelog content empty after exhausting all options');
		return undef;
	}

	$m_main{engine} = $env->{engine};

	for $k (keys %m_main) {
		debug('release data: ' . $k . ': ' . $m_main{$k});
	}


	return $have_version_match;
}

sub create_announce {
	my $env = shift;
	my $f;

	my $out = Bluto::Announce::get_asciidoc(\%m_main, $env);
	if (!defined $out) {
		return undef;
	}

	my $fp_base = File::Spec->catfile(Bluto::Tree->announce_path);
	make_path($fp_base);
	my $fp = File::Spec->catfile($fp_base, $m_main{slug} . '-' . $m_main{version} . '.bluto.txt');
	open($f, '>', $fp) or (error('cannot open announce file: ' . $!) && return undef);
	print $f $out;
	close($f);
	debug('stored announce text file: ' . $fp);

	return $fp;
}

sub create_rss {
	my $env = shift;

	my $out = Bluto::Announce::get_asciidoc(\%m_main, $env);
	if (!defined $out) {
		return undef;
	}

	#return Bluto::RSS::to_string(\%m_main, $env, $out);
	return Bluto::RSS::to_file(\%m_main, $env, $out);
}

1;
