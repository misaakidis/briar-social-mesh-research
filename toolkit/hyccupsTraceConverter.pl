#! /usr/bin/perl

# UPB HYCCUPS -> the ONE trace converter
# Suitable for the "full_output.txt" from
# https://crawdad.org/upb/hyccups/20161017/index.html
# Implementation based on ../dieselnetConverter.pl

# Connectivity Assumption:
# A connection between two nodes is active as long as any of them can reach the other node.

# The ONE simulator creates a connection when any of the nodes emits an up event,
# and destroys the connection when any of the nodes emits a down event.

package Toolkit;
use strict;
use warnings;
use FileHandle;
use Getopt::Long;

my $usage = '
usage: -out <output file name> [-minDuration <milliseconds>] [-loops <number of loops>] [-loopStart <milliseconds>] [-loopEnd <milliseconds>] [-help]
       <input file name>
';

my ($minDuration, $loops, $loopStart, $loopEnd, $help, $outFileName);

GetOptions(
  "out=s"=> \$outFileName,
  "minDuration:i"=> \$minDuration,
  "loops:i"=> \$loops,
  "loopStart:i"=> \$loopStart,
  "loopEnd:i"=> \$loopEnd,
  "help|?!" => \$help
  );

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

# Input format:
# (Observer, Observed, Timestamp, Duration)
# Output format:
# (Timestamp, Action, Host1, Host2, [up/down])

# set loops and loop[Start/End] arguments if not given
if (!defined($minDuration)) {
  $minDuration = 1000;
}

if (!defined($loops)) {
  $loops = 1;
}

# important: if loopStart is different than 0, or loopEnd does not allign with 24h,
# you also need to adjust the beginning of day in SocialRouter!

if (!defined($loopStart)) {
  # the timestamp of the first trace
  $loopStart = 1330701836000;
}

if (!defined($loopEnd)) {
  # the timestamp of the last active trace
  $loopEnd = 1336127473000;
}

# setup input and output file handlers
my $inputFile = shift @ARGV;
my $inFh = new FileHandle;
my $outFh = new FileHandle;
$inFh->open("<$inputFile") or die "Can't open input file $inputFile";
$outFh->open(">$outFileName") or die "Can't create outputfile $outFileName";

# read whole file to array
my @lines = <$inFh>;
$inFh->close();

my @output;

# sort traces by timestamp
@lines = sort
{
  my ($ahost1, $ahost2, $atime, $aduration) = $a =~ m/(\d+),(\d+),(\d+),(\d+)/;
  my ($bhost1, $bhost2, $btime, $bduration) = $b =~ m/(\d+),(\d+),(\d+),(\d+)/;
  $atime <=> $btime;
} @lines;

# array to keep the timestamp of the last host to disconnect in a pair of hosts
my @hostsTraceEnd;

foreach (@lines) {
  if (m/^\s$/) {
    # skip empty lines
    next;
  }

  # parse hyccups trace
  my ($host1, $host2, $time, $duration) =
    m/(\d+),(\d+),(\d+),(\d+)/;
  die "Invalid input line: $_" unless ($host1 and $host2);

  # skip traces before loopStart
  next if ($time < $loopStart);

  # skip traces after loopEnd
  last if ($time > $loopEnd);

  # bump duration to minDuration
  if ($duration < $minDuration) {
    $duration = $minDuration;
  }

  # host ids in ONE are zero-based
  $host1--;
  $host2--;

  # get index for hosts pair
  my @sortedHosts = sort { $a <=> $b } ($host1, $host2);
  my $sortedHostsIndex = join("0", @sortedHosts);

  # compute the end timestamp of this trace
  my $traceEnd = $time + $duration;

  for (my $i = 0; $i < $loops; $i++) {

    # adjust time for loop, starting at previous loopEnd and discarding delay until loopStart
    my $adjLoop = $i * ($loopEnd - $loopStart);

    # add CONN up event (duplicate up events have no effect to the simulation when hosts are already connected)
    my $timeAdj = $time + $adjLoop;
    push(@output, "$timeAdj\tCONN\t$host1\t$host2\tup");
    
    # if this trace starts after the traceEnd of the previous connection between the hosts
    # add CONN down event at the timestamp when the last of them disconnected
    # (remember that traces have already been sorted)
    if (defined($hostsTraceEnd[$sortedHostsIndex]) && $time > $hostsTraceEnd[$sortedHostsIndex]) {
      my $connEndTime = $hostsTraceEnd[$sortedHostsIndex] + $adjLoop;
      push(@output, "$connEndTime\tCONN\t$host1\t$host2\tdown");
    }
  }

  # if this is the first time these two nodes connect to each other,
  # or if this trace lasts longer than an active trace of the other host,
  # update hostsTraceEnd
  if (!defined($hostsTraceEnd[$sortedHostsIndex]) || $traceEnd > $hostsTraceEnd[$sortedHostsIndex]) {
    $hostsTraceEnd[$sortedHostsIndex] = $traceEnd;
  }
}

my $NUMOFHOSTS = 73;

# iterate $hostsTraceEnd, write pending CONN down events
# (duplicate conn down events do not affect the simulation)
for (my $host1 = 0; $host1 < $NUMOFHOSTS; $host1++ ) {
  for (my $host2 = $host1 + 1; $host2 < $NUMOFHOSTS; $host2++ ) {
    my $sortedHostsIndex = join("0", $host1, $host2);
    if (defined($hostsTraceEnd[$sortedHostsIndex])) {
      for (my $i = 0; $i < $loops; $i++) {
        my $adjLoop = $i * ($loopEnd - $loopStart);
        my $connEndTime = $hostsTraceEnd[$sortedHostsIndex] + $adjLoop;
        push(@output, "$connEndTime\tCONN\t$host1\t$host2\tdown");
      }
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

# print all the result lines to output file
print $outFh join("\n", @output);

$outFh->close();