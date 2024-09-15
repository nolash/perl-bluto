package Bluto::Archive;

use Cwd;
use File::Basename qw/basename fileparse/;
use Digest::SHA;

use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto::Tree qw/release_path/;
use File::Path qw / make_path /;


sub seal {
	my $targz = shift;
	my $keygrip = shift;
	# TODO: intended to be numeric flags but now we just use the first bit to force sign or not
	my $safe = shift; 

	if (!defined $keygrip) {
		if ($safe) {
			error('have no signing key and safe bit set');
			return undef;
		}
	}

	my $h = Digest::SHA->new('sha256');
	$h->addfile($targz);
	my $z = $h->hexdigest;
	debug('calculated sha256 ' . $z . ' for archive ' . $targz);
	my $hp = $targz . '.sha256';
	my $f;
	open($f, ">$hp") or (error('could not open digest file: ' . $!) && return undef);
	print $f $z . "\t" . basename($targz) . "\n";
	close($f);

	if (!defined $keygrip) {
		warn('skipping signature due to missing key');
		return $z;
	}

	my @cmd = ('gpg', '-a', '-b', '-u', $keygrip, $hp);
	system(@cmd);
	if ($?) {
		error('failed sign with key '. $keygrip);
		unlink($hp);
		return undef;
	}

	return $z;
}

sub create {
	my $release = shift;
	my $env = shift;
	my $flags = shift;

	my $keygrip = $release->{author_maintainer}[2];

	my $old_dir = cwd;

	chdir($env->{content_dir});

	my $targz_local = undef;
	my $targz_stem = $release->{slug} . '-' . $release->{version};

	my $rev = `git rev-parse HEAD --abbrev-ref`;
	if (!defined $rev) {
		error('unable to determine revision');
		chdir($old_dir);
		return undef;
	}
	chomp($rev);
	my $targz = $targz_stem . '+build.' . $rev . '.tar.gz';
	my $targz_base = File::Spec->catfile(Bluto::Tree->release_path, $release->{slug});
	make_path($targz_base);
	$targz_local = File::Spec->catfile($targz_base, $targz);

	if (! -f $targz_local ) {
		debug("no package file found, looked for: " . $targz_local);
		my @cmd = ('git', 'archive', $release->{tag_prefix} . $release->{version}, '--format', 'tar.gz', '-o', $targz_local);
		system(@cmd);
		if ($?) {
			error("package file generation fail: " . $e);
			unlink($targz);
			chdir($old_dir);
			return undef;
		}

#		my $cmd = Git::Repository::Command(['git', 'archive', '--format=tar.gz', '-o', $targz]);
#		my $e = $cmd->stderr();
#		$cmd->close();
#		if ($cmd->exit()) {
#			error("package file generation fail: " . $e);
#		}

		if (! -f $targz_local ) {
			error("package generation reported ok but still no file");
			chdir($old_dir);
			return undef;
		}

		my $seal = seal($targz_local, $keygrip, $flags & 1);
		if (!defined $seal) {
			error("failed sealing archive");
			unlink($targz_local);
			chdir($old_dir);
			return undef;
		}
		info('sealed archive as sha256 ' . $seal . ' signed by ' . $keygrip);
	} else {
		info("using existing package file: " . $targz_local);
		warn("existing package file is not being checked in any way 8|");
	}

	chdir($old_dir);
	
	return $targz_local;
}

1;
