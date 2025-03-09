package Bluto::Yaml;

use File::Basename qw/basename/;
use Bluto::Log qw/error info debug warn trace/;
use Bluto::Tree;


sub yaml_path {
	my $release = shift;

	my $fp_base = File::Spec->catfile(Bluto::Tree->announce_path);
	if ( ! -d $fp_base) {
		make_path($fp_base);
	}
	my $fp = File::Spec->catfile($fp_base, $release->{slug} . '.bluto.yaml');
	return $fp;
}

sub add_existing_releases {
	my $release = shift;
	my $yr = shift;

	my $fp = yaml_path($release);

	if ( ! -f $fp ) {
		debug("no existing release yaml");
		return $yr;
	}
	my $yf = YAML::Tiny->read($fp);
	for my $k (keys %{$yf->[0]->{releases}}) {
		if (!defined $k) {
			continue;
		}
		debug("processing file " . $fp);
		debug("processing key " . $k);
		if (defined $yr->{releases}->{$k}) {
			error("already have version in yaml: " . $k);
			return $yr;
		}
		debug("adding existing release to yaml: " . $k);
		$yr->{releases}->{$k} = $yf->[0]->{releases}->{$k};	
	}

	return $yr;
}

sub add_release_yaml {
	my $release = shift;
	my $yb = shift;
	my $yr = shift;
	my $env = shift;
	
	if (!defined $yb->{releases}) {
		$yb->{releases} = {};
	}

	$yr->{timestamp} = $release->{timeobj}->epoch;
	$yr->{archive} = 'sha256:' . $release->{archive};
	$yb->{releases}->{$env->{version}} = $yr;

	$yb = add_existing_releases($release, $yb);

	return YAML::Tiny->new($yb);
}

sub to_file {
	my $release = shift;
	my $y = shift;
	my $keygrip = shift;

	my $fp = yaml_path($release);

	$y->write($fp);

	# DRY with Bluto/Archive.pm
	my $keygrip = $release->{_author_maintainer}->[2];
	debug('using keygrip for yaml: ' . $keygrip);

	my $h = Digest::SHA->new('sha256');
	$h->addfile($fp);
	my $z = $h->hexdigest;
	debug('calculated sha256 ' . $z . ' for yaml ' . $fp);

	my $hp = $fp . '.sha256';
	my $f;
	open($f, ">$hp") or (error('could not open yaml digest file: ' . $!) && return undef);
	print $f $z . "\t" . basename($fp) . "\n";
	close($f);

	if (!defined $keygrip) {
		warn('skipping yaml signature due to missing key');
		return $fp;
	}

	my @cmd = ('gpg', '-a', '-b', '-u', $keygrip, $hp);
	system(@cmd);
	if ($?) {
		error('failed sign with key '. $keygrip);
		unlink($hp);
		return undef;
	}
	return $fp;
}

1;
