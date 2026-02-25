#!/usr/bin/perl -w
#https://www.ibm.com/support/pages/node/283137
#strings - pull strings out of a binary file

#
# This script takes as input the dump file generated on windows
# and the output file to write the parsed data to
#
use strict;
use warnings FATAL => 'all';
use open IO => ":raw";

$/ = "\0";
my $inputFile = $ARGV[0];
my $outputFile = $ARGV[1];

open (INPUT, "< $inputFile") or die $!;
open (OUTPUT, "> $outputFile");
while (<INPUT>)
{
    while (/([\040-\176\s]{4,})/g)
    {
        my $line = $1;
        print OUTPUT $1, "\n" if ($line =~ />(BIP\d{4})/) ;
        print OUTPUT $1, "\n" if ($line =~ />(BIP\w{4})/) ;
    }

}
close INPUT;
close OUTPUT;

__END__