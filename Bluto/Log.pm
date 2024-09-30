package Bluto::Log;

use Exporter qw/import/;
our @EXPORT = qw/error info debug warn trace/;
our $VERSION = 0.0.1;

our $fh = STDERR;

sub error($) {
	print $fh "\e[0;91m" . shift . "\e[0m\n";
}

sub warn($) {
	print $fh "\e[0;93m" . shift . "\e[0m\n";
}

sub debug($) {
	print $fh "\e[0;90m" . shift . "\e[0m\n";
}

sub info($) {
	print $fh "\e[0;92m" . shift . "\e[0m\n";
}

sub debug($) {
	print $fh "\e[0;94m" . shift . "\e[0m\n";
}

sub trace($) {
	print $fh "\e[0;90m" . shift . "\e[0m\n";
}

1;
