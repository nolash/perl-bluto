package Bluto;

use DateTime;
use File::Basename qw/ basename /;
use File::Path qw / make_path /;

use Bluto::Log qw/error info debug warn trace/;
use Bluto::Archive;
use Bluto::Announce;
use Bluto::Tree;
use Bluto::SemVer;
use Bluto::RSS;
use Bluto::Yaml;

use constant { VCS_TAG_PREFIX => 'v' };
#use constant { VERSION => '0.0.1' };
our $VERSION = '0.0.3' ;

our %config;
our $have_version_match = undef;
our @m_tech;
our @m_url;
our @m_vcs;
our @m_src;
our @m_contributors;
#our @m_author_maintainer = [undef, undef, undef];
#our @m_author_origin = [undef, undef, undef];
our %m_main = (
	name => undef,
	slug => undef,
	version => undef,
	summary => undef,
	license => undef,
	copyright => undef,
	tag_prefix => VCS_TAG_PREFIX,
	changelog => undef,
	archive => undef,
	time => undef,
	timeobj => undef,
	#tech_main => undef,
	tech => undef,
	vcs => \@m_vcs,
	src => \@m_src,
	uri => undef,
	url => \@m_url,
	_author_maintainer => undef,
	author_maintainer => undef,
	author_origin => undef,
	contributors => \@m_contributors,
	engine => undef,
);

sub version {
	return $VERSION;
}

sub _set_single {
	my $cfg = shift;
	my $cfg_k = shift;
	my $main_k = shift;
	my $need = shift;

	my $v = $cfg->{$cfg_k};
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

	return _set_triple('author', $cfg, $k, $need);
}

sub _set_contributor {
	my $cfg = shift;
	my $v = shift;
	my $k = shift;
	my $need = shift;

	return _set_triple('contributor', $cfg, $k, $need);
}

sub _set_triple {
	my $pfx = shift;
	my $cfg = shift;
	my $k = shift;
	my $need = shift;
	my $name;
	my $email;
	my $pgp;
	
	#$m_main{'_' . $pfx . '_' . $k} = [];
	#my $cfg_k = $pfx . ':' . $k;
	my $v = $cfg->{$k}->{name};
	# TODO if if if...
	if (defined $v) {
		$name = $cfg->{$k}->{name};
		if (ref($name) eq 'ARRAY') {
			$v = undef;
		} else {
			$email = $cfg->{$k}->{email};
			if (ref($email) eq 'ARRAY') {
				$email = undef;
			}
			$pgp = $cfg->{$k}->{pgp};
			if (ref($pgp) eq 'ARRAY') {
				$pgp = undef;
			}
		}
	}

	if ($need && !defined $v) {
		error('required ' . $pfx . ' data not set: ' . $cfg_k);
		return 1;
	}

	$m_main{'_' . $pfx . '_' . $k}[0] = $name;
	if (defined $email) {
		$m_main{'_' . $pfx . '_' . $k}[1] = $name . ' <' . $email . '>';
	}
	$m_main{'_' . $pfx . '_' . $k}[2] = $pgp;
	$m_main{$pfx . '_' . $k} = $name;
	return 0;
}

#sub _check_ini {
sub _check_yml {
	my $env = shift;

	#my $fp = File::Spec->catfile($env->{src_dir}, 'bluto.ini');
	my $fp = File::Spec->catfile($env->{src_dir}, 'bluto.yml');
	if ( ! -f $fp ) {
		error('yml file not found: ' . $fp);
		return 1;
	}
	debug('using yml file: ' . $fp);
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

	$fp = File::Spec->catfile($env->{src_dir}, 'VERSION');
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
	my $r = 0;
	my $release = shift;
	my $env = shift;

	return Bluto::Tree::prepare($release, $env);
}

sub check_sanity {
	my $env = shift;
	my $r = 0;

	$r += _check_readme($env);	
	#$r += _check_ini($env);
	$r += _check_yml($env);
	$r += _check_version($env);

	return $r;
}

sub from_yaml {
	my $cfg_m = shift;
	my $cfg_v = shift;
	my $env = shift;

	my $version;
	if (!defined $env->{version}) {
		die "version missing";
	}
	$version = $env->{version};
	info('using version ' . $version);
	$m_main{version} = $version;

	$r += _set_single($cfg_m, 'name', 'name', 1);
	$r += _set_single($cfg_m, 'slug', 'slug', 1);
	$r += _set_single($cfg_m, 'summary', 'summary', 1);
	$r += _set_single($cfg_m, 'license', 'license', 1);
	$r += _set_single($cfg_m, 'copyright', 'copyright', 1);
	$r += _set_single($cfg_m, 'tech', 'tech', 1);
	$r += _set_author($cfg_m, 'maintainer', undef, 1);
	if ($r) {
		error('invalid configuration');
		return undef;
	}

	if (defined $cfg_m->{vcs}->{tag_prefix}) {
		$m_main{tag_prefix} = $cfg_m->{vcs}->{tag_prefix};
	}

	foreach my $v (@{$cfg_m->{locate}->{www}}) {
		warn('not checking url formatting for ' . $v);
		push(@m_url, $v);
	}

	foreach my $v (@{$cfg_m->{locate}->{vcs}}) {
		warn('not checking git formatting for ' . $v);
		push(@m_vcs, $v);
	}

	debug("contributor list: " . $cfg_v->{contributors});
	foreach my $v (@{$cfg_v->{contributors}}) {
		debug('have contributor: ' . $v);
		push(@m_contributors, $v);
	}

	foreach my $v(@{$cfg_m->{locate}->{www}}) {
		if (!defined $m_main{uri}) {
			$m_main{uri} = $v;
		}
		push(@m_uri, $v);
	}

	foreach my $v(@{$cfg_m->{locate}->{rel}}) {
		push(@m_uri, $v);
	}

	# TODO: simplify now that changelog file is explicitly named	
	# TODO: if have sha256, check against the contents
	push(@changelog_candidates, "CHANGELOG." . $m_main{version});
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

	$r = _prepare_out(\%m_main, $env);
	if ($r > 0) {
		error('output location preparations fail');
		return undef;	
	}

	#my $targz = Bluto::Archive::create($m_main{slug}, $m_main{version}, $m_main{author_maintainer}[2], $m_main{tag_prefix}, $env->{src_dir}, $env->{out_dir}, 0);
	my $targz = Bluto::Archive::create(\%m_main, $env, 1);
	if (!defined $targz) {
		error('failed to generate archive (yaml)');
		return undef;
	}

	my @targz_stat = stat ( $targz );

	if (!@targz_stat) {
		error('generated archive but could not find again in expected place: ' . $targz);
		return undef;
	}
	$m_main{timeobj} = DateTime->from_epoch( epoch => $targz_stat[9] );
	$m_main{time} = $m_main{timeobj}->stringify();
	foreach my $v ( @{$cfg_m->{locate}->{tgzbase}}) {
		warn('not checking targz base formatting for ' . $v);
		my $src = $m_main{slug} . '/' . basename($targz);
		push(@m_src, $v . '/' . $src);
	}
	
	if ($#m_src < 0) {
		error('no source bundle prefixes defined');
		return undef;
	}

	$m_main{engine} = $env->{engine};

	for $k (keys %m_main) {
		if ($k =~ /^[^_].*/) {
			debug('release data: ' . $k . ': ' . $m_main{$k});
		}
	}

	return $m_main{version};
}

sub from_config {
	my $cfg = shift;
	my $env = shift;

	my $version;
	if (defined $cfg->{version}) {
		$version = $cfg->{version};
	} else {
		$fn = File::Spec->catfile($env->{src_dir}, 'VERSION');
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
	$r += _set_author($cfg, 'maintainer', undef, 1);
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

	my $cfg_vars = $cfg->vars();
	foreach my $k ($cfg->vars()) {
		if ($k =~ /^changelog\.(.+)$/) {
			if ($m_main{version} eq $1) {
				if (defined $have_version_match) {
					croak('already have version defined for ' . $1);
				}
				debug('found version match in changelog for ' . $1);	

				$have_version_match = SemVer->new($1);
			}
		} elsif ($k =~ /^contributor:(.+)\.(\w+)$/) {
			if ($1 eq $m_main{version}) {
#				if (!defined $m_main{"_contributor_$2"}) {
#					if (_set_contributor($cfg, $1, $2, 0)) {
#						error('corrupted contributor record for ' . $1 . ': ' . $2);
#					}
#					debug('found contributor for ' . $1 . ': '. $2);
#				}
				push(@m_contributors, $cfg_vars->{$k});
				debug('found contributor for ' . $1 . ': '. $2 . ' -> ' . $cfg_vars->{$k});
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

#	for $k (keys %m_main) {
#		if ($k =~ /^contributor_(.+)/) {
#			push(@m_contributors, $m_main{$k});
#			debug("adding contributor string line: " . $k . " -> " . $m_main{contributors});
#		}
#	}

	for $k (keys %m_main) {
		if ($k =~ /^[^_].*/) {
			debug('release data: ' . $k . ': ' . $m_main{$k});
		}
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

sub create_yaml {
	my $y_base = shift;
	my $y_release = shift;
	my $env = shift;

	my $y = Bluto::Yaml::add_release_yaml(\%m_main, $y_base, $y_release, $env);
	my $fp = Bluto::Yaml::to_file(\%m_main, $y);

	debug('stored announce yaml file: ' . $fp);
}

1;
