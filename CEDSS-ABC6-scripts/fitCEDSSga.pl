#!/usr/bin/perl

use strict;

my %CONFIG = (
	      'CALIBERR' => 'energyerr.pl',
	      'CALIFILE' => 'cedss3.3-20120404-Urban-energy-match-totals',
	      'CALIBOUT' => 'calibout.txt',
	      'ERR1' => 'appliance.elect.error,appliance.gas.error,'
	      .'space.heating.elect.error,space.heating.gas.error,'
	      .'space.heating.oil.error,water.heating.elect.error,'
	      .'water.heating.gas.error,water.heating.oil.errpr',
	      'ERR2' => 'appliance.elect.abs.error,appliance.gas.abs.error',
	      'ERR3' => 'appliance.elect.abs.error,'
	      .'space.heating.elect.error,water.heating.elect.error',
	      'ERR1F' => 'sumsq',
	      'ERR2F' => 'sum',
	      'ERR3F' => 'sum',
	      'ERR1M' => '1',
	      'ERR2M' => '1',
	      'ERR3M' => '1',
	      'MULTI' => 'first',
	      );

if(scalar(@ARGV) < 1) {
  die "Usage: $0 [-config <option> <value>] <fitness file>\n";
}

while($ARGV[0] =~ /^-/) {
  my $opt = shift(@ARGV);

  if($opt eq '-config') {
    my $option = shift(@ARGV);
    my $value = shift(@ARGV);
    if(!defined($CONFIG{$option})) {
      die "Script $0 does not have configuration option $option\n";
    }
    $CONFIG{$option} = $value;
  }
}

my $fitnessfile = $ARGV[0];

my $exitstatus = 0;
if(open(FP, "<", $fitnessfile)) {
  $exitstatus = <FP>;
  $exitstatus =~ s/\s*$//;
  close(FP);
}
else {
  warn "Fitness file $fitnessfile not available ($!)\n";
}

if($exitstatus != 0) {
  # The run failed. Give an appropriate response in the fitness file
  open(FP, ">", $fitnessfile)
    or die "Cannot create fitness file $fitnessfile: $!\n";
  print FP "0\n0\n0\n";
  close(FP);
  exit 0;
}

# When running the calibration error script, XML files are sent as inputs.
# It is assumed all XML files ending -\d+.xml are relevant in directories
# immediately below the CWD.

my $cmd = "$CONFIG{'CALIBERR'} $CONFIG{'CALIFILE'} */*-[0-9][0-9]*.xml";

# The output of the calibration command is a CSV format with one line per
# output. This will be saved in case the user wants to read it.

system("$cmd > $CONFIG{'CALIBOUT'} 2> stderr-calib.txt")
  or die "Calibration command failed: $cmd ($!)\n";

# Read the CSV file and compute the fitnesses for each run
# individually. Note that fitness is the opposite sense to error, and
# we need a zero lower bound. Note also that the fitnesses need to be
# comparable measures for the purposes of fitness sharing (hence the
# $scale variable)

open(FP, "<", $CONFIG{'CALIBOUT'})
  or die "Cannot open calibration output file $CONFIG{'CALIBOUT'}: $!\n";

my @fitnesses;
my @fit1head = split(/,/, $CONFIG{'ERR1'});
my @fit2head = split(/,/, $CONFIG{'ERR2'});
my @fit3head = split(/,/, $CONFIG{'ERR3'});

my $headerline = <FP>;
$headerline =~ s/\s*$//;

my @headers = split(/,/, $headerline);

while(my $line = <FP>) {
  $line =~ s/\s*$//;
  my @cells = split(/,/, $line);

  my %data;

  for(my $i = 0; $i <= $#headers; $i++) {
    $data{$headers[$i]} = $cells[$i];
  }

  my @fitness;

  foreach my $dimension ([$CONFIG{'ERR1F'}, \@fit1head, $CONFIG{'ERR1M'}],
			 [$CONFIG{'ERR2F'}, \@fit2head, $CONFIG{'ERR2M'}],
			 [$CONFIG{'ERR3F'}, \@fit3head, $CONFIG{'ERR3M'}]) {
    my $fn = $$dimension[0];
    my $heads = $$dimension[1];
    my $scale = $$dimension[2];

    my $sum = 0;

    foreach my $head (@$heads) {
      my $entry = $data{$head};
      if(!defined($entry)) {
	die "Entry $head not defined in calibration file ",
	  "$CONFIG{'CALIBOUT'}\n";
      }
      if($fn eq 'SUM') {
	$sum += $entry;
      }
      elsif($fn eq 'SUMSQ') {
	$sum += $entry * $entry;
      }
      else {
	die "Function $fn not available in fitness script $0\n";
      }
    }

    push(@fitness, $scale / $sum);
  }

  push(@fitnesses, \@fitness);
}

close(FP);

# Now print the fitnesses to the fitness file. How to handle it depends on the
# MULTI configuration option.

open(FP, ">", $fitnessfile)
  or die "Cannot create fitness file $fitnessfile: $!\n";

for(my $i = 0; $i < 3; $i++) {
  if($CONFIG{'MULTI'} eq 'first') {
    print FP "$fitnesses[0][$i]\n";
  }
  elsif($CONFIG{'MULTI'} eq 'mean') {
    my $sum = 0;
    my $n = 0;

    foreach my $fitness (@fitnesses) {
      $sum += $$fitness[$i];
      $n++;
    }
    print FP $sum / $n, "\n";
  }
  elsif($CONFIG{'MULTI'} eq 'best') {
    my $best;

    foreach my $fitness (@fitnesses) {
      if(!defined($best) || $$fitness[$i] > $best) {
	$best = $$fitness[$i];
      }
    }
    print FP "$best\n";
  }
  elsif($CONFIG{'MULTI'} eq 'all') {
    my $first = 1;
    
    foreach my $fitness (@fitnesses) {
      if($first) {
	$first = 0;
      }
      else {
	print FP ",";
      }
      print FP $$fitness[$i];
    }

    print FP "/n";
  }
  else {
    die "Invalid setting for MULTI configuration option: $CONFIG{'MULTI'}\n";
  }
}

close(FP);
exit 0;
