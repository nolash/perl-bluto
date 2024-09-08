package Bluto::Tree;


use File::Spec;
use File::Path qw/ make_path /;

our $_release_path;
our $_announce_path;

sub release_path() {
	return $_release_path;
}
sub announce_path() {
	return $_announce_path;
}

sub prepare {
	my $release = shift;
	my $env = shift;

	$_release_path = File::Spec->catfile($env->{out_dir}, $release->{slug}, 'release');
	File::Path->make_path(release_path);
	$_announce_path = File::Spec->catfile($env->{out_dir}, $release->{slug}, 'announce');
	File::Path->make_path(announce_path);

	return 0;
}

1;
