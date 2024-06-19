#!/usr/bin/env perl

use Config::Simple;

my @keys = (
	'main.name',
	'main.slug',
	'main.version',
	'main.summary',
	'main.license',
	'main.uri',
	'main.tech',
	'vcs.tag_prefix',
	'author:maintainer.name',
	'author:maintainer.email',
	'author:maintainer.pgp',
	'key.rsa',
	'key.ed25519',
	'key.secp256k1',
	'fund.btc',
	'fund.eth',
	'fund.monero',
	'locate.www',
	'locate.vcs',
	'locate.tgzbase',
);

my $cfg = new Config::Simple(syntax=>'ini');
for my $k ( @keys ) {
	$cfg->param($k, '');
}

$cfg->param('changelog.0.0.0-alpha.1',  '');

print $cfg->as_string;
