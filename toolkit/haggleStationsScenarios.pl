#!/usr/bin/perl
use strict;
use warnings;

my $lastActiveConnectionTime = 987529;

open my $haggleOriginal, '<', '../datasets/haggle/haggle-one-cambridge-city-complete.tsv' or die $!;
open my $noStations, '>', '../datasets/haggle-original-without-stations.txt' or die $!;
open my $hybridStations, '>', '../datasets/haggle-original-hybrid-stations.txt' or die $!;

# Creates two new trace files based on the haggle dataset
# 1. noStations: Removes the stationary nodes
# 2. hybridStations: Turns stationary nodes into hybrid (they are connected with each other throughout the simulation)
# Students are nodeIds [0,35], and stationary nodes are nodeIds [36,51]

# for hybrid stations, add connections between nodes with id > 35 at the start of the simulation
for my $i (36..51) {
    for my $j ($i+1..51) {
        print $hybridStations "0\tCONN\t$i\t$j\tup\n";
    }
}

while (my $trace = <$haggleOriginal>) {
    chomp $trace;
    my ($time, $type, $node1, $node2, $status) = split '\t', $trace;

    # write to noStations if both node ids are less than or equal to 35
    if ($node1 <= 35 && $node2 <= 35) {
        print $noStations "$trace\n";
    }

    # write all traces to hybridStations
    print $hybridStations "$trace\n";
}

# for hybrid stations, close connections between nodes with id > 35 at the end of the simulation
for my $i (36..51) {
    for my $j ($i+1..51) {
        print $hybridStations "$lastActiveConnectionTime\tCONN\t$i\t$j\tdown\n";
    }
}

close $haggleOriginal;
close $noStations;
close $hybridStations;
