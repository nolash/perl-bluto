package Bluto::Cmd;

use Getopt::Long qw/ :config auto_help /;
use Cwd qw/ getcwd abs_path /;
use File::Spec;
use File::Path qw/make_path/;
use File::Copy;
use Digest::SHA;

use Bluto::SemVer;
use YAML::Tiny;

use Bluto::Log qw/debug error/;


my $force_version = undef;
my $force_help = 0;
my %env = (
	src_dir => File::Spec->catfile(getcwd, '.bluto'),
	version => undef,
	loglevel => undef,
);
my @opts_x;

sub croak {
	die(shift);
}

sub help {
	print("$0\n\nwould have shown help...\n");
	exit 0;
}

sub register_param {
	my $env_k = shift;
	my $env_v_default = shift;
	my $switch_long = shift,
	my $switch_short = shift,
	my $switch_typ = shift;
	$env{$env_k} = $v;

	if (!defined $switch_typ) {
		$switch_typ = "s";
	}
	if (defined $switch_long) {
		push(@opts_x, $switch_long . ':' . $switch_typ);
		push(@opts_x, \$env{$env_k});
	}
	if (defined $switch_short) {
		push(@opts_x, $switch_short . ':' . $switch_typ);
		push(@opts_x, \$env{$env_k});
	}
	debug("added env k $env_k switches $switch_long / $switch_short");
}

sub process_param {
	GetOptions(
		'd:s', \$env{src_dir},
		'v+', \$env{loglevel},
		'h+', \$force_help,
		'help+', \$force_help,
		@opts_x,
	);

	if ($force_help > 0) {
		help;
	}

	if (defined $env{version}) {
		$env{version} = SemVer->new($env{version});
	}

	if (defined $env{src_dir}) {
		make_path($env{src_dir});
	}

	foreach my $k (keys %env) {
		my $v = $env{$k};
		if (defined $v) {
			debug("env k $k v $v");
		} else {
			debug("env k $k not defined");
		}
	}
}

sub get_param {
	my $k = shift;
	return $env{$k};
}

sub get_version {
	if (defined $env{version}) {
		$env{version} = SemVer->new($env{version});
	}
	return $env{version};
}

sub base_config_path {
	return File::Spec->catfile($env{src_dir}, 'bluto.yml');
}

sub release_config_path {
	if (!defined $env{version}) {
		croak("release config path does not exist, version not set");
	}
	return File::Spec->catfile($env{src_dir}, $env{version} . '.yml');
}

sub base_config {
	my $fn = base_config_path();
	my $yi = YAML::Tiny->read($fn);
	return $yi->[0];
}

sub process_changelog {
	my $copy = shift;

	if (!defined $env{changelog_file}) {
		croak("changelog file missing");
	}

	my $h = Digest::SHA->new('sha256');
	$h->addfile($env{changelog_file});
	my $z = $h->hexdigest;
	debug('calculated sha256 ' . $z . ' for changelog ' . $env{changelog_file});
	if ($copy) {
		my $fp = File::Spec->catfile($env{src_dir}, 'CHANGELOG.' . $env{version});
		copy($env{changelog_file}, $fp);
	}
	return $z;
}

1;
