package Bluto::Announce;

use Template;

use Bluto::Log qw/error info debug warn trace/;

my $pos;

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
				$this = '=' x (length($last) - 1);
			} elsif ($_ =~ /^---/) {
				if ($last !~ /^\W+$/) {
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

	if (defined $env->{template_path}) {
		if (!$tt->process($env->{template_path}, $release, \$v)) {
			error('error processing template: '. $tt->error());
			$v = undef;
		}
	} else {
		debug("no template specified, using default");
		if (!defined $pos) {
			$pos = tell(Bluto::Announce::DATA);
		}
		seek(Bluto::Announce::DATA, $pos, 0);
		my $tpl = do { local $/; <Bluto::Announce::DATA>};
		if (!$tt->process(\$tpl, $release, \$v)) {
			error('error processing default template (sorry!!): '. $tt->error());
			$v = undef;
		}
	}

	$v = _adapt_headings($v);

	return $v;
}

1;

__DATA__

Release announcement: [% name %]
===


Version release: [% version %]

License: [% license %]

Copyright: [% copyright %]

Author: [% author_maintainer %]

Source bundles
--------------

[% FOREACH v IN src %]* [% v %]
[% END %]

VCS
---

[% FOREACH v IN vcs %]* [% v %]
[% END %]

ONLINE RESOURCES
----------------

[% FOREACH v IN url %]* [% v %]
[% END %]

[% FOREACH v IN contributors %][% IF !have_contributors %]CONTRIBUTORS IN THIS VERSION
----------------------------

[% SET have_contributors = 1 %][% END %]* [% v %]
[% END %][% IF have_contributors %]

[% END %]CHANGELOG
---------

[% changelog %]

-----

Generated by [% engine %] at [% time %]Z
