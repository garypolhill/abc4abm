#!/usr/bin/perl

# analyseCEDSS.pl
#
# Gary Polhill, 18 April 2017
#
# Script to get the results from runs that have completed but not been
# properly analysed because of a bug in an earlier version of the code
# causing division by zero. This script is based on sampleCEDSS.pl as
# at the above date.

use strict;

# Globals

# Ranges and nulls

my %param = ('bioboost' => ['FLOAT', 0, 10, 0],
	     'credit' => ['FLOAT', -20, 10, 'none'],
	     'boostceil' => ['INT', 0, 2500, 0],
	     'habitadjust' => ['FLOAT', 0, 1, 0],
	     'maxlinks' => ['INT', 5, 20, 0],
	     'visits' => ['INT', 1, 5, 0],
	     'hedonism1' => ['FLOAT', 0, 5, 'none'],
	     'hedonism2' => ['FLOAT', 'hedonism1', 5, 'none'],
	     'egoism1' => ['FLOAT', 0, 5, 'none'],
	     'egoism2' => ['FLOAT', 'egoism1', 5, 'none'],
	     'biospherism1' => ['FLOAT', 0, 5, 0],
	     'biospherism2' => ['FLOAT', 'biospherism1', 5, 0],
	     'frame1' => ['FLOAT', 0, 1, 0],
	     'frame2' => ['FLOAT', 'frame1', 1, 0],
	     'planning1' => ['INT', 1, 40, 'none'],
	     'planning2' => ['INT', 'planning1', 40, 'none'],
	     'newsubcatapp' => ['INT', 0, 5, 1],
	     'newsubcatstep' => ['INT', 0, 8, 'max']
  );

my %paramRerr = ('biospheric.boost.factor' => 'bioboost',
		 'credit.multiple.limit' => 'credit',
		 'biospheric.boost.ceiling' => 'boostceil',
		 'habit.adjustment.factor' => 'habitadjust',
		 'max.links' => 'maxlinks',
		 'visits.per.step' => 'visits');

# Replications and other commandline options

my $prep = 8;			# Replications with the same parameters & files
my $rep = 8;			# Number of resamples of the files
my $null = 0;			# All model parameters that can have null values
my %nulls;			# Some model parameters that can have null
my %set;			# Set some parameters to a specified value
my $cleanup = 0;		# Clean up
my $zip = 0;			# Zip up (implies clean)

# Default commands to run the model and compute errors on those runs

my $errcmd = './energyerr.pl';

# Calibration error files

my $urban = 'cedss3.3-20120404-Urban-energy-match-totals.csv';
my $rural = 'cedss3.3-20120423-Rural-energy-match-totals.csv';
my $calib = $urban;

# Command line arguments

while($ARGV[0] =~ /^-/) {
  my $opt = shift(@ARGV);

  if($opt eq '-urban') {
    $calib = $urban;
  }
  elsif($opt eq '-rural') {
    $calib = $rural;
  }
  elsif($opt eq '-cleanup') {
    $cleanup = 1;
  }
  elsif($opt eq '-zip') {
    $zip = 1;
    $cleanup = 1;
  }
  else {
    die "Unrecognized commandline option: $opt\n";
  }
}

my $rundir = shift(@ARGV);

my @files;

# Read the parameters

my %sample;
my $genefile = "${rundir}.csv";

push(@files, $genefile);

unless(-e "$genefile") {
  die "Parameter sample file $genefile does not exist\n";
}
open(FP, "<", $genefile) or die "Cannot read sample file $genefile: $!\n";

while(my $line = <FP>) {
  $line =~ s/\s+$//;

  my ($key, $value) = split(/,/, $line);

  $sample{$key} = $value;
}

close(FP);

# Add other files to the list of files to be zipped

my $out = "${rundir}.out";
my $err = "${rundir}.err";

push(@files, $out, $err);

# Compute the errors and save them to a file

# Get all of the XML files we are going to use

my $results = "${rundir}-results.csv";
my @xmls;

opendir(CWD, ".");
while(my $file = readdir(CWD)) {
  next if $file =~ /^\./;
  if(substr($file, 0, length($rundir)) eq $rundir && -d "$file") {
    opendir(SUB, $file);
    while(my $subfile = readdir(SUB)) {
      next if $subfile =~ /^\./;
      if(substr($subfile, 0, length($file) + 1) eq $file."-"
	 && $subfile =~ /\.xml$/) {
	my $outfile = $subfile;
	$outfile =~ s/-(\w+)\.xml$/-output-\1\.csv/;
	push(@xmls, "$file/$subfile") if -e "$file/$outfile";
      }
      push(@files, "$file/$subfile");
    }
    closedir(SUB);
    push(@files, "$file");
  }
  elsif(substr($file, 0, length($rundir)) eq $rundir && $file =~ /\.txt$/) {
    push(@files, "$file");
  }
}
closedir(CWD);

# Build the CSV results file by parsing a call to energyerr.pl

if(scalar(@xmls) == 0) {
  die "No runs successfully generated output; cannot compute errors\n";
}

open(CSV, ">", $results) or die "Cannot write results file $results: $!\n";

my $exe = "$errcmd $calib ".join(" ", @xmls);

open(ERR, "-|", $exe) or die "Cannot connect to $exe: $!\n";

my $hline = <ERR>;
$hline =~ s/\s*$//;
my @headings = split(/,/, $hline);

print CSV "rundir";
foreach my $key (sort(keys(%sample))) {
  $key =~ s/\W/./g;		# Make the name of the key R friendly
  print CSV ",$key";
}
print CSV ",rep,prep";
foreach my $col (@headings) {
  if($col =~ /\.error$/ || defined($paramRerr{$col})) {
    print CSV ",$col";
  }
}
print CSV "\n";

while(my $line = <ERR>) {
  $line =~ s/\s*$//;
  my @cols = split(/,/, $line);

  print CSV "$rundir";
  foreach my $key (sort(keys(%sample))) {
    print CSV ",$sample{$key}";
  }

  # Get the rep and prep, which is assumed to be in the first column
  
  my $xml = $cols[0];
  if($xml =~ /\.xml$/) {
    $xml =~ s/\.xml$//;		# Remove the suffix
    my @ids = split(/-/, $xml);
    my ($rep, $prep) = ($ids[$#ids - 1], $ids[$#ids]);
    print CSV ",$rep,$prep";
  }
  else {
    print CSV ",NA,NA";
  }

  # Print the errors

  for(my $i = 0; $i <= $#headings; $i++) {
    if($headings[$i] =~ /\.error$/ || defined($paramRerr{$headings[$i]})) {
      print CSV ",$cols[$i]";
      if(defined($paramRerr{$headings[$i]})) {
	if(($cols[$i] == 0 && abs($sample{$paramRerr{$headings[$i]}}) > 0.0001)
	   || ($cols[$i] != 0 && 
	       abs(1 - ($sample{$paramRerr{$headings[$i]}} / $cols[$i]))
	       > 0.0001)) {
	  warn "Run $rundir $rep $prep seems to have unexpected parameter ",
	  "setting for $paramRerr{$headings[$i]}: $cols[$i] instead of ",
	  "$sample{$paramRerr{$headings[$i]}}\n";
	}
      }
    }
  }
  print CSV "\n";
}

close(ERR);
close(CSV);

if($zip) {
  my $cmd = "tar jcf \"$rundir.tar.bz2\" \"".(join("\" \"", @files))."\"";
  system($cmd);
  if(!-e "$rundir.tar.bz2") {
    die "Could not zip up with $cmd\n";
  }
}

if($cleanup) {
  my @dirs;
  foreach my $file (@files) {
    if(-d "$file") {
      push(@dirs, $file);
    }
    else {
      unlink $file or warn "Could not delete $file: $!\n";
    }
  }

  foreach my $dir (@dirs) {
    rmdir $dir or warn "Could not delete directory $dir: $!\n";
  }
}

exit 0;
