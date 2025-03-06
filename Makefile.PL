use strict;
use warnings;
use lib '.';
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME	=> 'Bluto',
	AUTHOR	=> q(Louis Holbrook <dev@holbrook.no>),
	VERSION_FROM	=> 'Bluto.pm',
	ABSTRACT	=> 'A simple-minded software packager',
	LICENSE	=> 'perl',
	EXE_FILES	=> [
		'bluto-gen',
		'bluto-pub',
	],
	PREREQ_PM	=> {
		'SemVer'	=> 0.10.1,
		'Template'	=> 2.66,
		'Digest::SHA'	=> 2.13,
		'XML::RSS'	=> 1.63,
		# package https://metacpan.org/pod/Bitcoin::Secp256k1
		'Bitcoin::Secp256k1'	=> 0.004,
	},
	TEST_REQUIRES	=> {},
);
