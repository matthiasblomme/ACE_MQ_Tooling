#!/usr/bin/perl

#
#
#

use strict;
use warnings FATAL => 'all';
use Proc::Find qw(find_proc proc_exists);

    # check if a program is running
my $pids = find_proc(name => 'IntegrationServer.exe');
foreach my $pid (@$pids) {
    print "pid = $pid\n";
}