#! /usr/bin/perl

# UPB HYCCUPS -> the ONE trace converter
# Suitable for the "full_output.txt" from
# https://crawdad.org/upb/hyccups/20161017/index.html
# Implementation based on ../dieselnetConverter.pl

package Toolkit;
use strict;
use warnings;
use FileHandle;
use Getopt::Long;

my $usage = '
usage: -out <output file name> [-minDuration <milliseconds>] [-help]
       <input file name>
';

my ($minDuration, $help, $outFileName);

GetOptions("out=s"=>\$outFileName, "minDuration:i"=>\$minDuration, "help|?!" => \$help);

if (not $help and (not $outFileName or not @ARGV)) {
  print "Missing required parameter(s)\n";
  print $usage;
  exit();
}

if ($help) {
  print 'UPB HYCCUPS trace converter.';
  print "\n$usage";
   print '
options:
out   Name of the output file
';
  exit();
}

# Input example:
# (Observer, Observed, Timestamp, Duration)
# 23,1,1330701836000,387000

# Output example:
# (Timestamp, Action, Host1, Host2, [up/down])
# 0 CONN 22 0 up
# 387 CONN 22 0 down

my $inputFile = shift @ARGV;
my $inFh = new FileHandle;
my $outFh = new FileHandle;
$inFh->open("<$inputFile") or die "Can't open input file $inputFile";
$outFh->open(">$outFileName") or die "Can't create outputfile $outFileName";

# read whole file to array
my @lines = <$inFh>;
$inFh->close();

my @output;

# sort observations by timestamp
@lines = sort
{
  #TODO: Use the regex ^\d+,\d+,\K\d+
  my ($ahost1, $ahost2, $atime, $aduration) = $a =~ m/(\d+),(\d+),(\d+),(\d+)/;
  my ($bhost1, $bhost2, $btime, $bduration) = $b =~ m/(\d+),(\d+),(\d+),(\d+)/;
  $atime <=> $btime;
} @lines;

# 2D array to keep observation end timestamps
my @observations;

foreach (@lines) {
  if (m/^\s$/) {
    next; # skip empty lines
  }
  my ($host1, $host2, $time, $duration) =
    m/(\d+),(\d+),(\d+),(\d+)/;
  die "Invalid input line: $_" unless ($host1 and $host2);

  # bump duration to minDuration
  if ($duration < $minDuration) {
    $duration = $minDuration
  }

  my $obsEndTime = $time + $duration;
  $observations[$host1][$host2] = $obsEndTime;

  # a connection is up while both host1 and host2 can reach each other
  # if host2 can also reach host1
  if (defined($observations[$host2][$host1])) {
    if ($obsEndTime <= $observations[$host2][$host1]) {
      # host ids in ONE are zero-based
      my $adjHost1 = $host1 - 1;
      my $adjHost2 = $host2 - 1;
      # add CONN up event
      push(@output, "$time\tCONN\t$adjHost1\t$adjHost2\tup");
      # find out which host disconnects first
      my $connEndTime = $obsEndTime <= $observations[$host2][$host1] ? $obsEndTime : $observations[$host2][$host1];
      # add CONN down event
      push(@output, "$connEndTime\tCONN\t$adjHost1\t$adjHost2\tdown");
    }
  }
}

# sort connection events by timestamp
@output = sort
{
  my ($t1) = $a =~ m/^(\d+)/;
  my ($t2) = $b =~ m/^(\d+)/;
  $t1 <=> $t2;
} @output;

my ($firstTime) = $output[0] =~ m/^(\d+)/;
print "Adjusting timestamps by $firstTime seconds\n";
foreach (@output) {
  my ($ts) = m/^(\d+)/;
  my $newTime = ($ts - $firstTime)/1000;
  s/$ts/$newTime/;
}

print $outFh "# Connection trace file for the ONE. Converted from $inputFile \n";
# print all the result lines to output file
print $outFh join("\n", @output);

$outFh->close();