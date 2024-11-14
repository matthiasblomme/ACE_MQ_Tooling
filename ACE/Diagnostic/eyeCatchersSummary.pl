#!/usr/bin/perl -w
#https://www.ibm.com/support/pages/node/283137

#
# This script takes the eyecatchers input file and parses it to make a list of how oftern
# each eyecatcher occures
#
use strict;
use warnings;
my %eyecatchers;

my $inputFile = $ARGV[0];
my $outputFile = $ARGV[1];

open (INPUT, "< $inputFile") or die $!;
	while (<INPUT>) {
		chomp;
		$eyecatchers{$_}++;
	}
close INPUT;

open(OUTPUT, "> $outputFile");
	print OUTPUT $_." ".$eyecatchers{$_}."\n" foreach (sort {$eyecatchers{$b} <=>$eyecatchers{$a}} keys %eyecatchers);
close OUTPUT;

__END__