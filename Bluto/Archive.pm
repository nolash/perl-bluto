package Bluto::Archive;

use Cwd;
use Log::Term::Ansi qw/error info debug warn trace/;

sub create {
	my $slug = shift;
	my $version = shift;
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
	}

	chdir($old_dir);
	
	return $targz_local;
}

1;
