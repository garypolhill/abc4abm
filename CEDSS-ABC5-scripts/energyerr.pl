#!/usr/bin/perl
#
# energyerr.pl
#
# Compute calibration error in energy from various expts.

use FindBin;
use lib $FindBin::Bin;

use nlogo2R;
use strict;

my $appliances_word = "appliance";
				# Constant to adjust if headers of
                                # calibration files change
my $space_word = "space";	# Ditto

if(scalar(@ARGV) < 2) {
  die "Usage: $0 <calibration file> <XML files...>\n";
}

my $calfile = shift(@ARGV);

if(!-T "$calfile") {
  die "Calibration file $calfile must be a text file in CSV format\n";
}

open(CAL, "<$calfile") or die "Cannot open calibration file $calfile\n";

my $line = <CAL> or die "No first line in calibration file\n";
$line =~ s/\s*\z//;

my @keys = split(",", $line);

if(scalar(@keys) == 0) {
  die "First line of calibration file must specify field names\n";
}

$line = <CAL> or die "No second line in calibration file\n";
$line =~ s/\s*\z//;

my @values = split(",", $line);

if(scalar(@values) == 0) {
  die "Second line of calibration must specify field values\n";
}

close(CAL);

my %calib;
my @appliance_keys;
my @space_keys;
my $rw_appliance_energy = 0;
my $rw_space_energy = 0;
my $rw_energy_total = 0;
for(my $i = 0; $i <= $#keys; $i++) {
  if($keys[$i] =~ /./ && $values[$i] =~ /./) {
    $calib{$keys[$i]} = $values[$i];
  }
  if($keys[$i] =~ /$appliances_word/) {
    push(@appliance_keys, $keys[$i]);
    $rw_appliance_energy += $values[$i];
  }
  elsif($keys[$i] =~ /$space_word/) {
    push(@space_keys, $keys[$i]);
    $rw_space_energy += $values[$i];
  }
  $rw_energy_total += $values[$i];
}
my $rw_appliance_ratio;

if(scalar(@appliance_keys) == 0) {
  warn "Could not find any headings containing appliances word \"",
    "$appliances_word\" in calibration file $calfile. Ratio of appliance ",
    "energy to total and absolute and relative appliance errors will not ",
    "be computed.\n";
  $rw_appliance_ratio = "NA";
}
else {
  $rw_appliance_ratio = $rw_appliance_energy / $rw_energy_total;
}
if(scalar(@space_keys) == 0) {
  warn "Could not find any headings containing space word \"$space_word\" ",
    "in calibration file $calfile. Absolute and relative space errors will ",
    "not be computed.\n";
}

my @pdata;
my @edata;
foreach my $xml (@ARGV) {
  open(XML, "<$xml") or die "Cannot open XML file $xml: $!\n";

  my @expt = <XML>;

  close(XML);

  my @path = split(/\//, $xml);
  pop(@path);
  my $dir = (scalar(@path) == 0) ? '.' : join('/', @path);

  my @final = grep(/final>.*<\/final/, @expt);
  my @timelimit = grep(/timeLimit/, @expt);
  my @params = grep(/variable=/, @expt);
  my @values = grep(/value=/, @expt);
  my @repetitions = grep(/repetitions=/, @expt);

  my $reps;

  foreach my $line (@repetitions) {
    if($line =~ /repetitions=\"(\d+)\"/) {
      $reps = $1;
    }
  }

  if(!defined($reps)) {
    warn "Cannot find repetitions in experiment file $xml. Assuming 1.\n";
    $reps = 1;
  }

  my @plots;
  my @worlds;
  my @myplots;

  my $quot = '&quot;';

  foreach my $line (@final) {
    if($line =~ /my-export-all-plots\s+${quot}(.*)${quot}/) {
      my $root = $1;
      if(scalar(@myplots) > 0) {
	warn "Have already picked up a my-export-all-plots in experiment file",
	" $xml, and now found another such line (argument \"$root\"), which",
	" will be ignored.\n";
      }
      else {
	push(@myplots, $root);
	$root = substr($root, 0, -4);
	my $x = 0;
	my $filename = "$root-$x.csv";
	while(-e "$dir/$filename") {
	  push(@myplots, $filename);
	  $x++;
	  $filename = "$root-$x.csv";
	}
      }
    }
    elsif($line =~ /export-all-plots\s+${quot}(.*)${quot}/) {
      my $plotfile = $1;
      push(@plots, $plotfile);
      if($reps > 1) {
	warn "Experiment file $xml has $reps repetitions, but uses ",
	"export-all-plots \"$plotfile\" to output data. This will get ",
	"overwritten with each repetition so only data from the last run ",
	"will be retained.\n";
      }
    }
    elsif($line =~ /export-world\s+${quot}(.*)${quot}/) {
      my $worldfile = $1;
      push(@worlds, $worldfile);
      if($reps > 1) {
	warn "Experiment file $xml has $reps repetitions, but uses ",
	"export-world \"$worldfile\" to output data. This will get ",
	"overwritten with each repetition so only data from the last ",
	"run will be retained.\n";
      }
    }
  }

  for(my $n = 0; $n < $reps; $n++) {
    my %param;

    for(my $i = 0; $i <= $#params; $i++) {
      my $key;
      my $value;

      if($params[$i] =~ /variable=\"(.*)\"/) {
	$key = $1;
      }

      if($values[$i] =~ /value=\"(.*)\"/) {
	$value = $1;
	$value =~ s/$quot//g;
      }

      if(defined($key) && defined($value)) {
	$param{$key} = $value;
      }
    }

    my $timesteps;
    for(my $i = 0; $i <= $#timelimit; $i++) {
      if($timelimit[$i] =~ /steps=\"(.*)\"/) {
	$timesteps = $1;
      }
    }

    die "Cannot find timelimit in experiment file $xml\n"
      if !defined($timesteps);

    my %caliberr;

    my @searched;

    my @search;

    if($reps == 1) {
      push(@search, @plots) if scalar(@plots) > 0;
      push(@search, @worlds) if scalar(@worlds) > 0;
      push(@search, $myplots[$n]) if defined($myplots[$n]);
    }
    else {
      push(@search, $myplots[$n]) if defined($myplots[$n]);
      push(@search, @plots) if scalar(@plots) > 0 and $n == $#myplots;
      push(@search, @worlds) if scalar(@worlds) > 0 and $n == $#myplots;
    }

    my $run_appliance_energy = 0;
    my $run_space_energy = 0;
    my $run_energy_total = 0;
    
    foreach my $output (@search) {
      my ($headers, $data) = nlogo2R::readfile("$dir/$output", 0);

      for(my $i = 0; $i <= $#$headers; $i++) {
	if($$headers[$i] =~ /^Total.energy.use.(.*)$/) {
	  my $element = $1;

	  my $element2 = $element;
	  $element2 =~ s/\./-/g;

	  my $e = defined($calib{$element}) ? $element : $element2;

	  if(defined($calib{$e})
	     || $e =~ /$appliances_word/ || $e =~ /$space_word/) {
	    my $calibration = $calib{$e};
	    my $total = 0;

	    for(my $step = $timesteps - 4; $step < $timesteps; $step++) {
	      $total += $data->[$step]->[$i];
	    }

	    if(defined($calib{$e})) {
	      $caliberr{$e} = $total - $calibration;
	      $run_energy_total += $total;
	    }
	    if($e =~ /$appliances_word/) {
	      $run_appliance_energy += $total;
	    }
	    elsif($e =~ /$space_word/) {
	      $run_space_energy += $total;
	    }
	  }
	  else {
	    push(@searched, $$headers[$i]);
	  }
	}
	else {
	  push(@searched, $$headers[$i]);
	}
      }
    }

    if(scalar(keys(%caliberr)) != scalar(keys(%calib))) {
      my @notincaliberr;

      foreach my $key (keys(%calib)) {
	push(@notincaliberr) if !defined($caliberr{$key});
      }

      if(scalar(@notincaliberr) > 0) {
	warn "Not found the following requested calibration keys in the ",
	"output data:\n";

	warn "\t", join(", ", @notincaliberr), "\n";

	warn "\nSearched:\n\t";

	warn join("\n\t", @searched), "\n\n";
      }

      my @notincalib;

      foreach my $key (keys(%caliberr)) {
	push(@notincalib) if !defined($calib{$key});
      }

      if(scalar(@notincalib) > 0) {
	warn "Generated calibration error for the following keys that were ",
	"not requested!:\n";

	warn "\t", join(", ", @notincalib), "\n\n";
      }

      die "Mismatch in computed (", scalar(keys(%caliberr)), ") and requested",
      " (", scalar(keys(%calib)), ") calibration entities\n";
    }

    my $error = 0;

    foreach my $key (keys(%caliberr)) {
      $error += abs($caliberr{$key});
    }

    $param{'.file'} = $xml;

    if($reps > 1 && scalar(@myplots) > 1) {
      $param{'.plot.file'} = $myplots[$n];
    }
  
    $caliberr{'error'} = $error;
    $caliberr{'abs.space'} = abs($rw_space_energy - $run_space_energy);
    $caliberr{'rel.space'} = $run_space_energy / $rw_space_energy;
    $caliberr{'abs.appliance'} = abs($rw_appliance_energy
				     - $run_appliance_energy);
    $caliberr{'rel.appliance'} = $run_appliance_energy / $rw_appliance_energy;
    $caliberr{'abs.total'} = abs($rw_energy_total - $run_energy_total);
    $caliberr{'rel.total'} = $run_energy_total / $rw_energy_total;
    $caliberr{'abs.appliance.rat'} = abs(($rw_appliance_energy
					  / $rw_energy_total)
					 - ($run_appliance_energy
					    / $run_energy_total));
    $caliberr{'rel.appliance.rat'} = (($run_appliance_energy
				       / $run_energy_total)
				      / ($rw_appliance_energy
					 / $rw_energy_total));

    push(@pdata, \%param);
    push(@edata, \%caliberr);
  }
}

my %pheadings;

foreach my $pdatum (@pdata) {
  foreach my $key (keys(%$pdatum)) {
    $pheadings{$key} = 1;
  }
}

my @phead = sort(keys(%pheadings));
my @ehead = sort(keys(%calib));

for(my $i = 0; $i <= $#phead; $i++) {
  print "," if $i > 0;

  my $Rphead = $phead[$i];
  $Rphead =~ s/\W/./g;

  print $Rphead;
}

for(my $i = 0; $i <= $#ehead; $i++) {
  my $Rehead = $ehead[$i];
  $Rehead =~ s/\W/./g;

  print ",$Rehead.error";
}

for(my $i = 0; $i <= $#ehead; $i++) {
  my $Rehead = $ehead[$i];
  $Rehead =~ s/\W/./g;

  print ",$Rehead.p.error";
}

for(my $i = 0; $i <= $#ehead; $i++) {
  my $Rehead = $ehead[$i];
  $Rehead =~ s/\W/./g;

  print ",$Rehead.abs.error";
}

print ",calibration.error,abs.space.error,rel.space.error,",
  "abs.appliances.error,rel.appliances.error,abs.total.error,rel.total.error,",
  "abs.appliances.ratio.error,rel.appliances.ratio.error\n";

for(my $i = 0; $i <= $#pdata; $i++) {
  for(my $j = 0; $j <= $#phead; $j++) {
    print "," if $j > 0;

    if(defined($pdata[$i]->{$phead[$j]})) {
      print $pdata[$i]->{$phead[$j]};
    }
    else {
      print 'NA';
    }
  }

  for(my $j = 0; $j <= $#ehead; $j++) {
    print ",";

    if(defined($edata[$i]->{$ehead[$j]})) {
      print $edata[$i]->{$ehead[$j]};
    }
    else {
      print 'NA';		# Shouldn't happen!
    }
  }

  for(my $j = 0; $j <= $#ehead; $j++) {
    print ",";

    if(defined($edata[$i]->{$ehead[$j]})) {
      print ($edata[$i]->{$ehead[$j]} / $calib{$ehead[$j]});
    }
    else {
      print 'NA';		# Shouldn't happen!
    }
  }

  for(my $j = 0; $j <= $#ehead; $j++) {
    print ",";

    if(defined($edata[$i]->{$ehead[$j]})) {
      print abs($edata[$i]->{$ehead[$j]});
    }
    else {
      print 'NA';		# Shouldn't happen!
    }
  }

  foreach my $extra ('error', 'abs.space', 'rel.space', 'abs.appliance',
		     'rel.appliance', 'abs.total', 'rel.total',
		     'abs.appliance.rat', 'rel.appliance.rat') {
    if(defined($edata[$i]->{$extra})) {
      print ",", $edata[$i]->{$extra};
    }
    else {
      print ",NA";		# Really shouldn't happen!
    }
  }
  print "\n";
}







