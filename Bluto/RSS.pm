package Bluto::RSS;

use File::Spec;
use DateTime;

use XML::RSS;
use Template;

use Log::Term::Ansi qw/error info debug warn trace/;
use Bluto::Version;


sub get_feed_filepath {
	my $release = shift;
	my $env = shift;
	
	my $fn = $release->{slug} . '.bluto.rss';
	my $fp = File::Spec->catfile($env->{feed_dir}, $fn);
	return $fp;
}

sub process {
	my $release = shift;
	my $env = shift;
	my $body = shift;

	my $rss_title = $release->{slug} . ' ' . $release->{version};
	my $rss;
	$rss = XML::RSS->new;
	my $feed_file = get_feed_filepath($release, $env);
	if ( -f $feed_file ) {
		info('found existing feed file ' . $feed_file);
		$rss->parsefile( $feed_file );
		foreach my $v ( @{$rss->{items}} ) {
			debug('rss contains: ' . $v->{title});
			if ($v->{title} eq $rss_title) {
				error('already have rss entry for ' . $rss_title);
				return undef;
			}
		}
	} else {
		info('starting new feed file ' . $feed_file);
		$rss = XML::RSS->new(version => '1.0');
		$rss->channel (
			title => $release->{name},
			link => $release->{url},
			description => $release->{summary},
			dc => {
				date => DateTime->now()->stringify(),
				creator => $release->{author_maintainer}[0],
				publisher => "$0 " . SemVer->new(Bluto::Version::VERSION). " (perl $^V)",
			},
		#		subject    => "Linux Software",
		#		creator    => 'scoop@freshmeat.net',
		#		publisher  => 'scoop@freshmeat.net',
		#		rights     => 'Copyright 1999, Freshmeat.net',
		#		language   => 'en-us',
		#	},
		#	  taxo => [
		#	       'http://dmoz.org/Computers/Internet',
		#	            'http://dmoz.org/Computers/PC'
		#	               ]
		);
	}

	# check if we already have the title
	foreach my $item ( $rss->{items}) {
		if ( defined $item->[0] && $item->[0]{title} eq $rss_title ) {
			error('already have published record for ' . $rss_title);
			return undef;
		}
	}

	debug('outs '. $release->{url});

	$rss->add_item (
		title => $rss_title,
		link => $release->{src}[0],
		description => $body,
		dc => {
			date => $release{time},
		},
	#  dc => {
		#       subject  => "X11/Utilities",
		#            creator  => "David Allen (s2mdalle at titan.vcu.edu)",
		#               },
		#                  taxo => [
		#                       'http://dmoz.org/Computers/Internet',
		#                            'http://dmoz.org/Computers/PC'
		#                               ]
	);

	return $rss;
}

sub to_string {
	my $release = shift;
	my $env = shift;
	my $body = shift;

	my $rss = process($release, $env, $body);
	return $rss->as_string;
}

sub to_file {
	my $release = shift;
	my $env = shift;
	my $body = shift;

	my $rss = process($release, $env, $body);
	$rss->save(get_feed_filepath($release, $env));
}

1;
