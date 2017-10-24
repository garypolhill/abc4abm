#!/usr/bin/perl

use strict;
use Cwd;

my %CONFIG = (
	      'SETUP' => './setup-cedss.pl',
	      'NETLOGO' => '/mnt/apps/netlogo-5.2.1',
	      'JAVA' => '/mnt/apps/java/jdk1.7.0_51/bin/java',
	      'MODEL' => 'CEDSS3.4-20170413.nlogo',
	      'STEPS' => '44',
	      'DATADIR' => 'input-files',
	      'RECIPADJ' => 'true',
	      'MATRIX' => 'cedss3.3-slm-20120325full.csv',
	      'DW' => 'dwu-',
	      'PATCH' => 'script-patch-20141126.csv',
	      'DWELLAPP' => 'dwellings-appliances-Filtered-UR-20150203.csv',
	      'CAPITAL' => 'script-capital-20141126.csv',
	      'DWELLINGS' => 'script-dwellings-Urban-20141126.csv',
	      'INSULATION' => 'cedss3.3-insulation20140221.csv',
	      'RETROINS' => 'script-insulation-retrodiction-20141126.csv',
	      'RETROAPP' => 'script-appliance-retrodiction-20150203.csv',
	      'MAXINCAT' => 'cedss3.3-maximum-in-category-20141207.csv',
	      'SURVEYQUERY' => 'A SEQ urban',
	      'RUNDIR' => 'rundir',
	      'MEMORY' => '2048m',
	      'REP' => 1,
	      'PREP' => 1,

	      # Configurations that change according to scenario or
	      # setup conditions are configured here using these three
	      # lowercase parameters, which are then used to set up
	      # the corresponding proper parameters using subroutines

	      'basic' => 'basic2',
	      'scenario' => 's100',
	      'external' => 't1a',

	     );


if(scalar(@ARGV) < 1) {
  die "Usage: $0 [-config <option> <value>] <input file>\n";
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

&config_external($CONFIG{'external'}, \%CONFIG);
&config_scenario($CONFIG{'scenario'}, \%CONFIG);
&config_basic($CONFIG{'basic'}, \%CONFIG);
print "$CONFIG{'basic'}$CONFIG{'scenario'}$CONFIG{'external'}\n";

my $genefile = $ARGV[0];

my %search;

open(FP, "<", $genefile) or die "Cannot open input file $genefile: $!\n";
my $lineno = 0;
while(my $line = <FP>) {
  $lineno++;

  $line =~ s/\s*$//;
  next if length($line) == 0;

  my @cells = split(/,/, $line);

  if(scalar(@cells) < 2) {
    die "Error in input file $genefile: fewer than two cells on line ",
      "$lineno\n";
  }

  if(length($cells[0]) == 0) {
    die "Error in input file $genefile: cell 1 on line $lineno is empty\n";
  }
  if(length($cells[1]) == 0) {
    die "Error in input file $genefile: cell 2 on line $lineno is empty\n";
  }

  $search{$cells[0]} = $cells[1];
}

close(FP);

# set new-subcategory-steps

if($search{'newsubcatstep'} eq 'max') {
  $search{'newsubcatstep'} = $CONFIG{'STEPS'} + 1;
}

for(my $prep = 1; $prep <= $CONFIG{'PREP'}; $prep++) {
  my $rundir = "$CONFIG{'RUNDIR'}-$prep";
  
  my $setupcmd = "\"$CONFIG{'SETUP'}\" "
    ."-uselinks "
    ."-netlogo \"$CONFIG{'NETLOGO'}\" "
    ."-java \"$CONFIG{'JAVA'}\" "
    ."-nsteps $CONFIG{'STEPS'} "
    ."-model \"$CONFIG{'DATADIR'}/$CONFIG{'MODEL'}\" "
    ."-setup biospheric-boost-factor $search{'bioboost'} "
    ."-setup credit-multiple-limit $search{'credit'} "
    ."-setup biospheric-boost-ceiling $search{'boostceil'} "
    ."-setup triggers-file \"$CONFIG{'DATADIR'}/$CONFIG{'TRIGGERS'}\" "
    ."-setup maximum-in-category-file \"$CONFIG{'DATADIR'}/$CONFIG{'MAXINCAT'}\" "
    ."-setup appliances-replacement-file \"$CONFIG{'DATADIR'}/$CONFIG{'REPLACEMENT'}\" "
    ."-setup appliances-fuel-file \"$CONFIG{'DATADIR'}/$CONFIG{'FUEL'}\" "
    ."-setup energy-prices-file \"$CONFIG{'DATADIR'}/$CONFIG{'PRICES'}\" "
    ."-setup external-influences-file \"$CONFIG{'DATADIR'}/$CONFIG{'EXTINF'}\" "
    ."-setup insulation-update-file \"$CONFIG{'DATADIR'}/$CONFIG{'INSUPDATE'}\" "
    ."-setup habit-adjustment-factor $search{'habitadjust'} "
    ."-setup max-links $search{'maxlinks'} "
    ."-setup new-subcategory-appliances-per-step $search{'newsubcatapp'} "
    ."-setup new-subcategory-steps $search{'newsubcatstep'} "
    ."-setup reciprocal-adjustment $CONFIG{'RECIPADJ'} "
    ."-setup social-link-matrix-file \"$CONFIG{'DATADIR'}/$CONFIG{'MATRIX'}\" "
    ."-setup visits-per-step $search{'visits'} "
    ."-setting dw $CONFIG{'DW'} "
    ."\"$rundir\" "	      # Name of directory to set up and run in
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'PATCH'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'DWELLAPP'}\" "
    .&rangestr($search{'hedonism1'}, $search{'hedonism2'}, "uniform")." "
    .&rangestr($search{'egoism1'}, $search{'egoism2'}, "uniform")." "
    .&rangestr($search{'biospherism1'}, $search{'biospherism2'}, "uniform")." "
    .&rangestr($search{'frame1'}, $search{'frame2'}, "uniform")." "
    .&rangestr($search{'planning1'}, $search{'planning2'}, "uniformint")." "
    ."\"$CONFIG{'SURVEYQUERY'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'INCOME'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'CAPITAL'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'DWELLINGS'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'INSULATION'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'RETROINS'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'APPLIANCES'}\" "
    ."\"$CONFIG{'DATADIR'}/$CONFIG{'RETROAPP'}\" ";

  $setupcmd =~ s/$CONFIG{'DATADIR'}\/null/null/g;
  print "$setupcmd\n";

  my $runcmd = "./run-$rundir.sh $CONFIG{'MEMORY'}";

  system("$setupcmd > $rundir-stdout-setup.txt 2> $rundir-stderr-setup.txt");
  if(!-x "$rundir/run-$rundir.sh") {
    die "Setup command \"$setupcmd\" did not successfully create ",
    "$rundir/run-$rundir.sh\n";
  }

  my $cwd = cwd();
  chdir($rundir) or die "Cannot chdir to $rundir: $!\n";

  for(my $run = 1; $run <= $CONFIG{'REP'}; $run++) {
    system("$runcmd $run > stdout-run$run.txt 2> stderr-run$run.txt");
    if(!-e "$rundir-output-$run.csv") {
      warn "Run command \"$runcmd $run\" did not successfully create ",
      "$rundir-output-$run.csv\n";
    }
    if(-s "$rundir-$run.err" > 0) {
      warn "Run command \"$runcmd $run\" led to CEDSS error file ",
      "$rundir-$run.err with non-zero size\n";
    }
  }

  chdir($cwd) or die "Cannot chdir back to $cwd: $!\n";
}

exit 0;

sub rangestr {
  my ($range1, $range2, $distn) = @_;
  
  if($range1 > $range2) {
    return "\'$distn($range2,$range1)\'";
  }
  else {
    return "\'$distn($range1,$range2)\'";
  }
}

sub config_external {
  my ($external, $CONFIG) = @_;

  if($external eq 't1a') {
    $$CONFIG{'EXTINF'} = 'null';
  }
  elsif($external eq 't1b') {
    $$CONFIG{'EXTINF'} = '/external-influences-steady-20141216g.csv';
  }
  elsif($external eq 't1c') {
    $$CONFIG{'EXTINF'} = 'external-influences-varying-20141216g1.csv';
  }
  else {
    die "External influences configuration $external not recognised\n";
  }
}

sub config_scenario {
  my ($scenario, $CONFIG) = @_;

  if($scenario =~ /^s1..$/) {
    $$CONFIG{'APPLIANCES'} = 'cedss3.4-appliances-S-midimp-20150203.csv';
    $$CONFIG{'FUEL'} = 'cedss3.4-appliances-fuel-S-fastimp-20150204.csv';
    $$CONFIG{'REPLACEMENT'} = 'cedss3.4-replacements-S-fastimp-20150203.csv';
    $$CONFIG{'INSUPDATE'} = 'null';
  }
  elsif($scenario =~ /^s2..$/) {
    $$CONFIG{'APPLIANCES'} = 'cedss3.4-appliances-S-fastimp-20150203.csv';
    $$CONFIG{'FUEL'} = 'cedss3.4-appliances-fuel-S-fastimp-20150204.csv';
    $$CONFIG{'REPLACEMENT'} = 'cedss3.4-replacements-S-fastimp-20150203.csv';
    $$CONFIG{'INSUPDATE'} = 'cedss3.4-insulation-update-S-fastimp-20160710.csv';
  }
  elsif($scenario =~ /^s3..$/) {
    $$CONFIG{'APPLIANCES'} = 'cedss3.4-appliances-S-regmidimp-20150203.csv';
    $$CONFIG{'FUEL'} = 'cedss3.4-appliances-fuel-S-regfastimp-20150204.csv';
    $$CONFIG{'REPLACEMENT'} = 'cedss3.4-replacements-S-regfastimp-20150203.csv';
    $$CONFIG{'INSUPDATE'} = 'null';
  }
  elsif($scenario =~ /^s4..$/) {
    $$CONFIG{'APPLIANCES'} = 'cedss3.4-appliances-S-regfastimp-20150203.csv';
    $$CONFIG{'FUEL'} = 'cedss3.4-appliances-fuel-S-regfastimp-20150204.csv';
    $$CONFIG{'REPLACEMENT'} = 'cedss3.4-replacements-S-regfastimp-20150203.csv';
    $$CONFIG{'INSUPDATE'} = 'cedss3.4-insulation-update-S-fastimp-20160710.csv';
  }
  else {
    die "Scenario configuration $scenario not recognised (policy)\n";
  }

  if($scenario =~ /^s.0.$/) {
    $$CONFIG{'INCOME'} = 'script-income-stable-20150106.csv';
  }
  elsif($scenario =~ /^s.2.$/) {
    $$CONFIG{'INCOME'} = 'script-income-2pcpa-20141217.csv';
  }
  elsif($scenario =~ /^s.4.$/) {
    $$CONFIG{'INCOME'} = 'script-income-4pcpa-20141216.csv';
  }
  else {
    die "Scenario configuration $scenario not recognised (economy)\n";
  }

  if($scenario =~ /^s..0$/) {
    $$CONFIG{'PRICES'} = 'cedss3.4-energy-prices-S-stable-20141216.csv';
  }
  elsif($scenario =~ /^s..2$/) {
    $$CONFIG{'PRICES'} = 'cedss3.4-energy-prices-S-2pcpa-20150106.csv';
  }
  elsif($scenario =~ /^s..4$/) {
    $$CONFIG{'PRICES'} = 'cedss3.4-energy-prices-S-4pcpa-20150106.csv';
  }
  else {
    die "Scenario configuration $scenario not recognised (prices)\n";
  }
}

sub config_basic {
  my ($basic, $CONFIG) = @_;

  if($basic eq 'basic1') {
    $$CONFIG{'TRIGGERS'} = 'triggers-20141214.csv';
  }
  elsif($basic eq 'basic2') {
    $$CONFIG{'TRIGGERS'} = 'null';
  }
  elsif($basic eq 'basic3') {
    $$CONFIG{'TRIGGERS'} = 'null';
  }
  elsif($basic eq 'basic4') {
    $$CONFIG{'TRIGGERS'} = 'triggers-20141214.csv';
  }
  else {
    die "Basic configuration $basic not recognised\n";
  }
}
