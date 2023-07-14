#!/usr/bin/perl

use strict;

# Open the input file and read the lines
open my $input_fh, '<', '../datasets/sociopatterns/office_id_rewrite.txt' or die "Cannot open input file: $!";
my @lines = <$input_fh>;
close $input_fh;

# Initialize an empty hashmap to store departments
my %departments;

# Iterate over each line and parse the department
foreach my $i (0 .. $#lines) {
  my ($originalUserId, $department) = split('\t', $lines[$i]);

  # If the department has not been seen before, initialize it with an empty array
  if (!$departments{$department}) {
    $departments{$department} = [];
  }

  # Add the rewritten userId to the array for the department
  push(@{$departments{$department}}, $i);
}

# Open the output file and write the userIds of the colleagues in the same department
open my $output_fh, '>', '../datasets/sociopatterns/office_interests.txt' or die "Cannot open output file: $!";

foreach my $i (0 .. $#lines) {
  my ($originalUserId, $department) = split('\t', $lines[$i]);

  my @colleagues = grep { $_ ne $i } @{$departments{$department}};
  my $outputLine = "$i " . join(',', @colleagues) . "\n";
  print $output_fh $outputLine;
}

close $output_fh;