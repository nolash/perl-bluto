package Bluto::Archive;

use Cwd;
use File::Basename qw/ basename /;
use Digest::SHA;

use Log::Term::Ansi qw/error info debug warn trace/;


sub seal {
	my $targz = shift;
	my $keygrip = shift;

	my $h = Digest::SHA->new('sha256');
	$h->addfile($targz);
	my $z = $h->hexdigest;
	debug('calculated sha256 ' . $z . ' for archive ' . $targz);
	my $hp = $targz . '.sha256';
	my $f;
	open($f, ">$hp") or (error('could not open digest file: ' . $!) && return undef);
	print $f $z . "\t" . basename($targz) . "\n";
	close($f);

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
	my $slug = shift;
	my $version = shift;
	my $keygrip = shift;
	my $git_prefix = shift;
	my $src_dir = shift;

	my $old_dir = cwd;

	chdir($src_dir);

	my $targz = $slug . '-' . $version . '.tar.gz';
	my $targz_local = File::Spec->catfile($src_dir, $targz);
	if (! -f $targz_local ) {
		#croak("no package file found, looked for: " . $targz);
		debug("no package file found, looked for: " . $targz);

		my @cmd = ('git', 'archive', $git_prefix . $version, '--format', 'tar.gz', '-o', $targz);
		system(@cmd);
		if ($?) {
			error("package file generation fail: " . $e);
			unlink($targz);
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
			return undef;
		}

		my $seal = seal($targz_local, $keygrip);
		if (!defined $seal) {
			error("failed sealing archive");
			unlink($targz);
			return undef;
		}
		info('sealed archive as sha256 ' . $seal . ' signed by ' . $keygrip);
	
	} else {
		info("using existing package file: " . $targz);
		warn("existing package file is not being checked in any way 8|");
	}

	

	chdir($old_dir);
	
	return $targz_local;
}

1;
