package Bluto::RSS;

use DateTime;

use XML::RSS;
use Template;

use Log::Term::Ansi qw/error info debug warn trace/;


sub to_file() {
	my $rss_title = $m_main{slug} . ' ' . $m_main{version};
	my $rss;
	$rss = XML::RSS->new;
	if ( -f $feed_file ) {
		info('found existing feed file ' . $feed_file);
		$rss->parsefile( $feed_file );
		foreach my $v ( @{$rss->{items}} ) {
			debug('rss contains: ' . $v->{title});
			if ($v->{title} eq $rss_title) {
				die('already have rss entry for ' . $rss_title);
			}
		}
	} else {
		info('starting new feed file ' . $feed_file);
		$rss = XML::RSS->new(version => '1.0');
		$rss->channel (
			title => $m_main{name},
			link => $m_main{git_upstream},
			description => $m_main{summary},
			dc => {
				date => DateTime->now()->stringify(),
				creator => $m_main{author_maintainer},
				publisher => "$0 " . SemVer->new(VERSION). " (perl $^V)",
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
			die('already have published record for ' . $rss_title);
		}
	}

	$rss->add_item (
		title => $rss_title,
		link => $targz,
		description => $out,
		dc => {
			date => $m_main{time},
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

	$rss->save($feed_file);
}

1;
