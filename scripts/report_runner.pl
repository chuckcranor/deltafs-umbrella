#!/usr/bin/env perl
#
# Copyright (c) 2017, Carnegie Mellon University.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
# 1. Redistributions of source code must retain the above copyright
#    notice, this list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 3. Neither the name of the University nor the names of its contributors
#    may be used to endorse or promote products derived from this software
#    without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT
# HOLDERS OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING,
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED
# AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#

#
# report_runner.pl  post-process mercury-runner results files and gen report
#
# 
# takes a list of *.result files generated by process_runner.pl and
# generates a short report.   our run_mercury_runner script takes
# the output from mercury runner and runs it through process_runner.pl
# and saves the results in $JOBDIRHOME for this job.   this script
# takes that output and generates a shorter report.
#
# cd $JOBDIRHOME
# report_runner.pl mercury-runner.12345/*.result
#


use strict;
use Getopt::Long;

my($rv, $tags);
my(%tagmap);

$rv = GetOptions(
    "tags=s"     => \$tags,
);

sub usage {
    my($msg) = @_;
    print STDERR "ERR: $msg\n" if ($msg ne '');
    print STDERR "usage: report_runner.pl [options] result-files ...\n";
    print STDERR "general options:\n";
    print STDERR "\t--tags  [tags]   tags\n";
    print STDERR "\n";
    print STDERR "tag format: str1=tag1,str2=tag2,...\n";
    exit(1);
}

usage() if ($rv != 1 || $#ARGV < 0);
if ($tags ne '') {
    @_ = split(/,/, $tags);
    foreach (@_) {
        next unless (/(\S+)=(\S+)/);
        $tagmap{$1} = $2;
    }
}

my(@res) = @ARGV;
my($lcv, $base, $prefix);
my(%n_nas, %b_nas, %n_sizes, %b_sizes, %n_prpcs, %b_prpcs);
my(%results, %lines);

# figure out what we've got from the filenames
foreach $lcv (@res) {
    $base = $lcv;
    $base =~ s@.*/@@;
    $prefix = substr($lcv, 0, length($lcv) - length($base));
    $base =~ s/.result$//;
    my($type, $orig_na, $one, $size) = split(/-/, $base);
    my($na) = $orig_na;
    foreach (sort keys %tagmap) {
        if (index($prefix, $_) != -1) {
            $na = $tagmap{$_};
            last;
        }
    }
    if ($type ne 'norm' && $type ne 'bulk') {
        print STDERR "unknown file $lcv, skip\n";
        next;
    }
    if ($type eq 'norm') {
        $type = 'normal';
        $n_nas{$na} = 1;
        $n_sizes{$size} = 1;
    } elsif ($type eq 'bulk') {
        $b_nas{$na} = 1;
        $b_sizes{$size} = 1;
    }

    if (!open(IN, "$lcv")) {
        print STDERR "open of $lcv failed - $!  ABORT\n";
        exit(1);
    }
    while (<IN>) {
        chop;
        my(@data) = split(" ");
        unless (substr($orig_na, 0, length($data[0])) eq $data[0]) {
            print STDERR "bad line data0 $lcv\n";
            next;
        }
        if ($data[1] =~ /\D/) {
            print STDERR "bad line data1 $lcv\n";
            next;
        }
        if ($type eq 'normal') {
            $n_prpcs{$data[1]} = 1;
        } elsif ($type eq 'bulk') {
            $b_prpcs{$data[1]} = 1;
        }
        $results{$type, $na, $size, $data[1]} = $data[2];
        $lines{$type, $na, $size} = $lines{$type, $na, $size} . "$_\n";
    }
    close(IN);
}

my(@nnas, @bnas, @nsizes, @bsizes, @nprpcs, @bprpcs);
@nnas = sort keys %n_nas;
@bnas = sort keys %b_nas;
@nsizes = sort { $a <=> $b } keys %n_sizes;
@bsizes = sort { $a <=> $b } keys %b_sizes;
@nprpcs = sort { $a <=> $b } keys %n_prpcs;
@bprpcs = sort { $a <=> $b } keys %b_prpcs;

print STDERR "normal xports: ", join(" ", @nnas), "\n";
print STDERR "normal  sizes: ", join(" ", @nsizes), "\n";
print STDERR "normal  prpcs: ", join(" ", @nprpcs), "\n";
print STDERR "bulk   xports: ", join(" ", @bnas), "\n";
print STDERR "bulk    sizes: ", join(" ", @bsizes), "\n";
print STDERR "bulk    prpcs: ", join(" ", @bprpcs), "\n";

sub report {
    my($name, $nar, $nszr, $nprpcr) = @_;
    my($got, $s, @hdr, $p, $n, $dat);
    $got = $#$nszr;
    return if ($got == -1);   # no data
    @hdr = ("#pRPCs", @$nar);

    foreach $s (@$nszr) {
        print "$name report, request size = $s, results in seconds per op\n";
        foreach (@hdr) {
            printf "%-10s ", $_;
        }
        print "\n";
        foreach $p (@$nprpcr) {
            printf "%-10s ", $p;
            foreach $n (@$nar) {
                $dat = $results{$name, $n, $s, $p};
                $dat = "0" unless (defined($dat));
                printf "%-10s ", $dat;
            }
            print "\n";
        }
        
        print "\n";
    }
    
}

sub report2 {
    my($name, $nar, $nszr, $nprpcr) = @_;
    my($n, $s);

    foreach $n (@$nar) {
        print "full results: $name $n\n";
        foreach $s (@$nszr) {
            print "size = $s\n";
            print $lines{$name, $n, $s};
        }
        print "\n";
    }
}

report("normal", \@nnas, \@nsizes, \@nprpcs);
report("bulk", \@bnas, \@bsizes, \@bprpcs);
print "";
report2("normal", \@nnas, \@nsizes, \@nprpcs);
report2("bulk", \@bnas, \@bsizes, \@bprpcs);
