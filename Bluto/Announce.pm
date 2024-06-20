package Bluto::Announce;

use Log::Term::Ansi qw/error info debug warn trace/;

sub _adapt_headings {
	my $f;
	my $last = undef;
	my $this = undef;
	my $r = '';
	my $v = shift;

	open(my $f, '<', \$v);
	while (<$f>) {
		$this = undef;
		if (defined $last) {
			if ($_ =~ /^===/) {
				$this = '=' x length($last);
			} elsif ($_ =~ /^---/) {
				if ($last !~ /^\W+$/) {
					debug('last is ' . $last);
					$this = '-' x (length($last) - 1);
				} else {
					$this = $_;
				}
			}

		}
		if (!defined $this) {
			$this = $_;
		}
		$r .= $this;
		$last = $_;
	}
	close($f);

	return $r;
}

sub get_asciidoc {
	my $release = shift;
	my $env = shift;

	my $v;

	my $tt = Template->new({
		INCLUDE_PATH => '.',
		INTERPOLATE => 1,
		ABSOLUTE => 1,
		});

	if (!$tt->process($env->{template_path}, $release, \$v)) {
		error('error processing template: '. $tt->error());
		$v = undef;
	}

	$v = _adapt_headings($v);

	return $v;
}

1;
