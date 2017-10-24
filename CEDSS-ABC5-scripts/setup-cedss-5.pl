#!/usr/bin/perl
#
# setup-cedss.pl
#
# Gary Polhill, The James Hutton Institute
# 14 November 2014
#
# Updated 12 December 2014
#
# Updated 30 June 2015
#
# Perl script to set up CEDSS experiments. The specification for this script
# is contained in a document circulated between Nick Gotts and Gary Polhill
# during October 2014
#
# Inputs to the script:
#
# 1. Layout (as CSV 'raster' style, with y coordinates descending from the
#    first line)
#
# 2. Survey information file and selector from that file
#
# 3. Incomes
#
# 4. Capital
#
# 5. Various probability distribuions
#
# 6. Pre-dwellings file
#
# 7. Insulation file
#
# 8. Appliances file
#
# 9. Appliances retrodiction file

use strict;
use Cwd 'abs_path';

# Defaults and globals

my $Rcmd = "/usr/bin/env Rscript";
my $capital_sample_arg = "uniform(0,1)";
my $dg_probs_arg = "uniform(0,1)";
my $loft_probs_arg = "uniform(0,1)";
my $wall_probs_arg = "uniform(0,1)";
my $boiler_probs_arg = "uniform(0,1)";
my $dishwasher_probs_arg = "uniform(0,1)";
my $dryer_probs_arg = "uniform(0,1)";
my $nlogo_file;
my $nsteps = 42;
my $use_links = 0;
my $java = "/usr/bin/java";
my $netlogo = "/mnt/apps/NetLogo-5.1.0";
my %setup;
my %string_param = ('patch-file' => 1,
		    'social-link-file' => 1,
		    'maximum-in-category-file' => 1,
		    'fuel-file' => 1,
		    'household-transition-matrix-file' => 1,
		    'patch-legend-file' => 1,
		    'household-file' => 1,
		    'usage-mode-matrix-file' => 1,
		    'external-influences-file' => 1,
		    'social-link-matrix-file' => 1,
		    'triggers-file' => 1,
		    'appliances-replacement-file' => 1,
		    'in-migrant-household-file' => 1,
		    'dwellings-file' => 1,
		    'insulation-update-file' => 1,
		    'appliances-fuel-file' => 1,
		    'insulation-upgrade-file' => 1,
		    'appliances-file' => 1,
		    'household-init-appliance-file' => 1,
		    'insulation-file' => 1,
		    'energy-prices-file' => 1);

my %script_param = ('patch-file' => 1,
		    'patch-legend-file' => 1,
		    'household-file' => 1,
		    'dwellings-file' => 1,
		    'household-init-appliance-file' => 1,
		    'appliances-file' => 1,
		    'insulation-file' => 1,
		    'output-file' => 1,
		    'steps' => 1,
		    'halt-after' => 1);

my %settings = ('ID' => 'B',
		'hh' => 'hh',
		'dw' => 'dw',
		'type' => 'NA',
		'income-band' => 'AS',
		'glazing' => 'D',
		'glazing-entry' => 'dg',
		'loft' => 'E,F',
		'loft-entry' => 'loft100,loft270',
		'wall' => 'G,H',
		'wall-entry' => 'cwi,swi',
		'has-insulation' => '1',
		'minimum' => 'minimum',
		'has-X-n' => 1,
		'gas-fuel' => 'AA',
		'electric-fuel' => 'AB',
		'oil-fuel' => 'AC',
		'electric-heating' => 'electric-heating',
		'gas-boiler-condensing' => 'AE',
		'p-condensing' => 0.05,
		'gas-conboiler-sub' => 'gas-conboiler-sub',
		'gas-boiler-sub' => 'gas-boiler-sub',
		'oil-boiler-condensing' => 'AF',
		'oil-conboiler-sub' => 'oil-conboiler-sub',
		'oil-boiler-sub' => 'oil-boiler-sub',
		'hob-type' => 'AL',
		'hob-type-gas-or-dual' => 1,
		'hob-type-electric' => 2,
		'hob-type-chob' => 3,
		'oven-type' => 'AM',
		'oven-type-gas' => 1,
		'gas-cooker-sub' => 'gas-cooker-sub',
		'dual-fuel-cooker-sub' => 'dual-fuel-cooker-sub',
		'electric-cooker-sub' => 'electric-cooker-sub',
		'chob-cooker-sub' => 'chob-cooker-sub',
		'n-fridge-freezer' => 'AG',
		'fridge-freezer-sub' => 'fridge-freezer-sub',
		'fridge-sub' => 'fridge-sub',
		'n-freezer' => 'AI',
		'freezer-sub' => 'freezer-sub',
		'assign-all' => 'washer-sub,CRT-TV-sub',
		'dishwasher' => 'AJ',
		'dishwasher-threshold' => 0,
		'dishwasher-sub' => 'dishwasher-sub',
		'dryer' => 'AK',
		'dryer-threshold' => 0,
		'dryer-sub' => 'dryer-sub',
		'appliance-name' => 'name',
		'appliance-subcategory' => 'subcategory',
		'appliance-1st-step' => 'first-step-available');

# Parse commandline arguments

if(scalar(@ARGV) == 1) {
  &read_config(shift(@ARGV), {"ARGS" => \@ARGV});
}

my @save_args = @ARGV;

while($ARGV[0] =~ /^-/) {
  my $opt = shift(@ARGV);

  if($opt eq '-R') {
    $Rcmd = shift(@ARGV);
  }
  elsif($opt eq '-read-settings') {
    &read_config(shift(@ARGV), {"SETTINGS" => \%settings});
  }
  elsif($opt eq '-read-setup') {
    &read_setup(shift(@ARGV), {"SETUP" => \%setup});
  }
  elsif($opt eq '-setting') {
    my $key = shift(@ARGV);
    my $value = shift(@ARGV);
    if(!defined($settings{$key})) {
      die "Setting $key not recognised. Recognised values are: ",
	join(", ", sort(keys(%settings))), "\n";
    }
    $settings{$key} = $value;
  }
  elsif($opt eq '-setup') {
    my $key = shift(@ARGV);
    my $value = shift(@ARGV);
    if(defined($script_param{$key})) {
      die "Setup $key is created by this script, and cannot be overridden ",
	"with $value\n";
    }
    $setup{$key} = $value;
  }
  elsif($opt eq '-capital-sample') {
    $capital_sample_arg = shift(@ARGV);
  }
  elsif($opt eq '-dg-probs') {
    $dg_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-loft-probs') {
    $loft_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-wall-probs') {
    $wall_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-boiler-probs') {
    $boiler_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-dishwasher-probs') {
    $dishwasher_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-dryer-probs') {
    $dryer_probs_arg = shift(@ARGV);
  }
  elsif($opt eq '-model') {
    $nlogo_file = shift(@ARGV);
  }
  elsif($opt eq '-nsteps') {
    $nsteps = shift(@ARGV);
  }
  elsif($opt eq '-java') {
    $java = shift(@ARGV);
  }
  elsif($opt eq '-netlogo') {
    $netlogo = shift(@ARGV);
  }
  elsif($opt eq '-uselinks') {
    $use_links = 1;
  }
  else {
    die "Option $opt not recognised\n";
  }
}

if(scalar(@ARGV) != 16) {
  die "Usage: $0 [-setting <setting> <value> ...]\n",
    "\t[-setup <CEDSS parameter> <value> ...]\n",
    "\t[-capital-sample <capital sample file>]\n",
    "\t[-dg-probs <double glazing probability sample file>]\n",
    "\t[-loft-probs <loft insulation probability sample file>]\n",
    "\t[-wall-probs <wall insulation probability sample file>]\n",
    "\t[-boiler-probs <boiler type probability sample file>]\n",
    "\t[-dishwasher-probs <dishwasher probability sample file>]\n",
    "\t[-dryer-probs <tumble dryer probability sample file>]\n",
    "\t[-model <CEDSS model file>]\n",
    "\t[-nsteps <number of steps to run the model for>]\n",
    "\t[-java <location of Java Runtime Environment>]\n",
    "\t[-netlogo <directory containing NetLogo installation>]\n",
    "\t[-R <R command>]\n\n",
    "\t<setup ID> <patch file> <survey file> <hedonism sample>\n",
    "\t<egoism sample> <biospherism sample> <frame sample>\n",
    "\t<planning sample> <survey query> <income file> <capital file>\n",
    "\t<dwellings file> <insulation file> <insulation retrodiction file>\n",
    "\t<appliances file> <appliances retrodiction file>\n";
}

my $setup_ID = shift(@ARGV);
my $patch_file = shift(@ARGV);
my $survey_file = shift(@ARGV);
my $hedonism_sample = shift(@ARGV);
my $gain_sample = shift(@ARGV);
my $norm_sample = shift(@ARGV);
my $frame_sample = shift(@ARGV);
my $planning_sample = shift(@ARGV);
my $survey_query = shift(@ARGV);
my $income_file = shift(@ARGV);
my $capital_file = shift(@ARGV);
my $dwellings_file = shift(@ARGV);
my $insulation_file = shift(@ARGV);
my $insulation_retrodiction_file = shift(@ARGV);
my $appliances_file = shift(@ARGV);
my $appliances_retrodiction_file = shift(@ARGV);

# Read in the data

my $patches = &read_patches($patch_file);

my $households = &read_database($survey_file);
if($survey_query ne 'ALL') {
  $households = &select_query($survey_query, $households);
}
my $n_households = scalar(@$households);

my @hedonisms = (($hedonism_sample =~ /\.csv$/ || $hedonism_sample =~ /\.txt$/)
		 ? &read_sample($hedonism_sample, $n_households)
		 : &sample_parse_R($Rcmd, $n_households, $hedonism_sample));
my @gains = (($gain_sample =~ /\.csv$/ || $gain_sample =~ /\.txt$/)
	     ? &read_sample($gain_sample, $n_households)
	     : &sample_parse_R($Rcmd, $n_households, $gain_sample));
my @norms = (($norm_sample =~ /\.csv$/ || $norm_sample =~ /\.txt$/)
	     ? &read_sample($norm_sample, $n_households)
	     : &sample_parse_R($Rcmd, $n_households, $norm_sample));
my @frames = (($frame_sample =~ /\.csv$/ || $frame_sample =~ /\.txt$/)
	      ? &read_sample($frame_sample, $n_households)
	      : &sample_parse_R($Rcmd, $n_households, $frame_sample));
my @plans = (($planning_sample =~ /\.csv$/ || $planning_sample =~ /\.txt$/)
	     ? &read_sample($planning_sample, $n_households)
	     : &sample_parse_R($Rcmd, $n_households, $planning_sample));

my @capital_samples = (($capital_sample_arg =~ /\.csv$/
			|| $capital_sample_arg =~ /\.txt$/)
		       ? &read_sample($capital_sample_arg, $n_households)
		       : &sample_parse_R($Rcmd, $n_households,
					 $capital_sample_arg));

my $incomes = &read_incomes($income_file);
my $capital = &read_capital($capital_file, $incomes, $income_file);
my $dwellings = &read_dwellings($dwellings_file, \%settings);
my ($insulation, $ins_state) = &read_insulation($insulation_file, \%settings);
my $rinsulation = &read_insulation_retrodiction($insulation_retrodiction_file);
my $appliances = &read_database($appliances_file);
my $rappliances = &read_appliance_retrodiction($appliances_retrodiction_file);

# Make a directory for the created files

if(-d "$setup_ID") {
  die "Directory for setup ID $setup_ID already exists. Choose another ID ",
    "or delete the directory\n";
}
mkdir $setup_ID or die "Cannot create directory $setup_ID: $!\n";

$setup{'nsteps'} = $nsteps;

&write_config("$setup_ID/$setup_ID.cfg", \@save_args, \%setup, \%settings);

# Prepare the setup parameters

$setup{'patch-file'} = "$setup_ID-patches.csv";
$setup{'patch-legend-file'} = "$setup_ID-patch-legend.csv";
$setup{'household-file'} = "$setup_ID-households.csv";
$setup{'dwellings-file'} = "$setup_ID-dwellings.csv";
$setup{'household-init-appliance-file'} = "$setup_ID-init-appliances.csv";
$setup{'appliances-file'} = "$setup_ID-appliances.csv";
$setup{'output-file'} = "$setup_ID-output.csv";
$setup{'insulation-file'} = "$setup_ID-insulation.csv";
$setup{'halt-after'} = $nsteps + 2;
				# halt-after should not be used to
				# stop the simulation; adding 2 to it
				# makes sure this is the case

# Write the files

my $patch_dwellings = &write_patches($setup_ID."/".$setup{'patch-file'},
				     $setup_ID."/".$setup{'patch-legend-file'},
				     $patches,
				     $patch_file,
				     $dwellings,
				     $dwellings_file,
				     \%settings);

my $n_dwellings = scalar(keys(%$patch_dwellings));

&write_households($setup_ID."/".$setup{'household-file'},
		  \%settings,
		  $households,
		  $survey_file,
		  $patch_dwellings,
		  $dwellings_file,
		  $patch_file,
		  $incomes,
		  $income_file,
		  $capital,
		  \@capital_samples,
		  $capital_file,
		  \@hedonisms,
		  \@gains,
		  \@norms,
		  \@frames,
		  \@plans);

my @dg_probs = (($dg_probs_arg =~ /\.csv$/ || $dg_probs_arg =~ /\.txt$/)
		? &read_sample($dg_probs_arg, $n_dwellings)
		: &sample_parse_R($Rcmd, $n_dwellings, $dg_probs_arg));

my @loft_probs = (($loft_probs_arg =~ /\.csv$/ || $loft_probs_arg =~ /\.txt$/)
		  ? &read_sample($loft_probs_arg, $n_dwellings)
		  : &sample_parse_R($Rcmd, $n_dwellings, $loft_probs_arg));

my @wall_probs = (($wall_probs_arg =~ /\.csv$/ || $wall_probs_arg =~ /\.txt$/)
		  ? &read_sample($wall_probs_arg, $n_dwellings)
		  : &sample_parse_R($Rcmd, $n_dwellings, $wall_probs_arg));

&write_dwellings($setup_ID."/".$setup{'dwellings-file'},
		 $patch_dwellings,
		 $households,
		 $survey_file,
		 \%settings,
		 \@dg_probs,
		 \@loft_probs,
		 \@wall_probs,
		 $rinsulation,
		 $insulation_retrodiction_file,
		 $insulation,
		 $ins_state,
		 $insulation_file);

my @boiler_probs = (($boiler_probs_arg =~ /\.csv$/
		     || $boiler_probs_arg =~ /\.txt$/)
		    ? &read_sample($boiler_probs_arg, $n_households)
		    : &sample_parse_R($Rcmd, $n_households,
				      $boiler_probs_arg));

my @dishwasher_probs = (($dishwasher_probs_arg =~ /\.csv$/
			 || $dishwasher_probs_arg =~ /\.txt$/)
			? &read_sample($dishwasher_probs_arg, $n_households)
			: &sample_parse_R($Rcmd, $n_households,
					  $dishwasher_probs_arg));

my @dryer_probs = (($dryer_probs_arg =~ /\.csv$/
		    || $dryer_probs_arg =~ /\.txt$/)
		   ? &read_sample($dryer_probs_arg, $n_households)
		   : &sample_parse_R($Rcmd, $n_households,
				     $dryer_probs_arg));

&write_initial_appliances($setup_ID."/"
			  .$setup{'household-init-appliance-file'},
			  \%settings,
			  $households,
			  $survey_file,
			  $appliances,
			  $appliances_file,
			  $rappliances,
			  $appliances_retrodiction_file,
			  \@boiler_probs,
			  \@dishwasher_probs,
			  \@dryer_probs);

&cp($appliances_file, $setup_ID."/".$setup{'appliances-file'}, $use_links);
&cp($insulation_file, $setup_ID."/".$setup{'insulation-file'}, $use_links);

my $copied_nlogo = &write_xml("$setup_ID/$setup_ID.xml",
			      $setup_ID,
			      \%setup,
			      \%string_param,
			      \%script_param,
			      $nlogo_file);

if($copied_nlogo ne "") {
  &write_sh("$setup_ID/run-$setup_ID.sh",
	    "$setup_ID.xml",
	    $java,
	    $copied_nlogo,
	    $setup_ID,
	    $netlogo);
}

exit 0;

##############################################################################
# Writing files subroutines
##############################################################################

# write_patches
#
# Write the patches file and patch legend file

sub write_patches {
  my ($file, $legend_file, $patches, $patch_file, $dwellings,
      $dwellings_file, $settings) = @_;

  open(FP, ">", $file) or die "Cannot create patch layout file $file: $!\n";

  my %patch_dwellings;
  foreach my $x (sort {$a <=> $b} keys(%$patches)) {
    my $ydata = $$patches{$x};

    foreach my $y (sort {$a <=> $b} keys(%$ydata)) {
      my $entry = $$ydata{$y};

      print FP "$x,$y,";
      
      if($entry eq "S") {
	print FP "street";
      }
      elsif($entry eq "J") {
	print FP "junction";
      }
      elsif($entry eq "P") {
	print FP "park";
      }
      elsif($entry eq "E") {
	print FP "empty";
      }
      else {
	print FP "dwelling,";
	
	my $entrycp = $entry;

	$entrycp =~ s/^$$settings{'dw'}//;
	
	if(defined($$dwellings{$entrycp})) {
	  print FP "$$settings{'dw'}$entrycp";
	  $patch_dwellings{$entrycp} = $$dwellings{$entrycp};
	}
	else {
	  my $valid_ids = join(", ", sort(keys(%$dwellings)));
	  die "No dwelling with ID $entry or $entrycp is defined in the ",
	    "dwellings file $dwellings_file (patch file $patch_file, x = $x, ",
	    "y = $y)\n\n(Valid IDs are $valid_ids)\n";
	}
      }
      
      print FP "\n";
    }
  }
  
  close(FP);

  open(FP, ">", $legend_file)
    or die "Cannot create patch legend file $legend_file: $!\n";

  print FP <<LEGEND_END;
dwelling,green
street,gray
park,52
junction,6
empty,black
LEGEND_END

  close(FP);
  
  return \%patch_dwellings;
}

# write_households
#
# Write the households file. This involves writing the data using the selected
# subset of the survey file. The dwellings are needed to get tenancy
# arrangements, which are used to look up income and capital given also the
# income band. Hedonsim, gain, norm, frame and plan are all created using
# samples provided as distributions on the command line. To use the same
# value for everyone, just provide all(X) as the distribution (where X is the
# value to use for everyone).

sub write_households {
  my ($file, $settings, $survey, $survey_file, $dwellings, $dwelling_file,
      $patch_file, $incomes, $income_file, $capitals, $capital_sample,
      $capital_file, $hedonism_sample, $gain_sample, $norm_sample,
      $frame_sample, $plan_sample) = @_;

  open(FP, ">", $file)
    or die "Cannot create household file $file: $!\n";

  print FP "id,type,dwelling,income,capital,hedonic,egoistic,biospheric,",
    "frame,planning\n";

  foreach my $hh (@$survey) {
    if(!defined($$hh{$$settings{'ID'}})) {
      die "Cannot determine the household ID in survey file $survey_file ",
	"using column identifier $$settings{'ID'} (check setting \'ID\')\n";
    }
    
    my $id = $$hh{$$settings{'ID'}};

    $id =~ s/^$$settings{'hh'}//; # Remove 'hh' prefix if present

    if(!defined($$dwellings{$id})) {
      die "Household $id in survey file $survey_file has no corresponding ",
	"dwelling ID in dwellings file $dwelling_file that is used in patch ",
	"file $patch_file\n";
    }

    my $tenancy = $dwellings->{$id}->[1];
    
    print FP "$$settings{'hh'}$id"; # All households have 'hh' prefix

    if($$settings{'type'} eq 'NA') {
      print FP ",household"	# Default household type if not in survey
    }
    else {
      if(!defined($$hh{$$settings{'type'}})) {
	die "Cannot determine household type in survey file $survey_file ",
	  "using column identifier $$settings{'type'} (check setting ",
	  "\'type\')\n";
      }
      print FP ",", $$hh{$$settings{'type'}};
    }
    
    print FP ",$$settings{'dw'}$id"; # All dwellings have 'dw' prefix

    if(!defined($$hh{$$settings{'income-band'}})) {
      die "Cannot determine income band in survey file $survey_file ",
	"using column identifier $$settings{'income-band'} (check setting ",
	"\'income-band\')\n";
    }
    my $band = $$hh{$$settings{'income-band'}};

    if(!defined($incomes->{$band})) {
      die "No income defined in income file $income_file for band $band ",
	"(household $id in household file $survey_file)\n";
    }
    if(!defined($incomes->{$band}->{$tenancy})) {
      die "No income defined in income file $income_file for band $band, ",
	"and tenancy $tenancy (household $id in household file ",
	"$survey_file and dwelling $id in dwelling file $dwelling_file)\n";
    }

    print FP ",[", join(" ", @{$incomes->{$band}->{$tenancy}}), "]";
				# Incomes are a list (info tab needs updating)
    
    my $which_capital = shift(@$capital_sample);
    if($which_capital < 0 || $which_capital > 1) {
      die "Invalid capital sample $which_capital -- must be in the range ",
	"[0, 1]\n";
    }

    if(!defined($capitals->{$band})) {
      die "No capital defined in capital file $capital_file for band $band ",
	"(household $id in household file $survey_file)\n";
    }
    if(!defined($capitals->{$band}->{$tenancy})) {
      die "No capital defined in capital file $capital_file for band $band, ",
	"and tenancy $tenancy (household $id in household file ",
	"$survey_file and dwelling $id in dwelling file $dwelling_file)\n";
    }
    
    my $capital_array = $capitals->{$band}->{$tenancy};
    my $i;
    for($i = 0; $i <= $#$capital_array; $i++) {
      if($capital_array->[$i]->[0] > $which_capital) {
	print FP ",", $capital_array->[$i]->[1];
	last;
      }
    }
    if($i > $#$capital_array) {
      die "Unable to allocate a capital for a households with income band ",
	"$band, tenancy $tenancy, and capital sample $which_capital from ",
	"capital file $capital_file (household $id in household file ",
	"$survey_file and dwelling $id in dwelling file $dwelling_file)\n";
    }

    print FP ",", shift(@$hedonism_sample);
    print FP ",", shift(@$gain_sample);
    print FP ",", shift(@$norm_sample);
    print FP ",", shift(@$frame_sample);
    print FP ",", shift(@$plan_sample);
    print FP "\n";
  }
  
  close(FP);
}

# write_dwellings
#
# Write the dwellings file. This involves selecting an insulation state.

sub write_dwellings {
  my ($file, $patch_dwellings, $survey, $survey_file, $settings, $dg_probs,
      $loft_probs, $wall_probs, $rinsulation, $rinsulation_file,
      $insn, $insn_states, $insn_file) = @_;

  open(FP, ">", $file) or die "Cannot create dwellings file $file: $!\n";

  print FP "id,type,tenure,insulation\n";

  my %hhkeys;
  for(my $i = 0; $i <= $#$survey; $i++) {
    my $hh_id = $survey->[$i]->{$$settings{'ID'}};
    $hh_id =~ s/^$$settings{'hh'}//;
    $hhkeys{$hh_id} = $$survey[$i];
  }

  foreach my $dwelling_id (sort(keys(%$patch_dwellings))) {
    my $entry = $$patch_dwellings{$dwelling_id};
    my $dw_type = $$entry[2];

    print FP "$$settings{'dw'}$dwelling_id";
				# enforce dw prefix for dwelling ID
    print FP ",", $dw_type;	# type
    print FP ",", $$entry[1];	# tenure

    my $hh = $hhkeys{$dwelling_id};

    # Now compute the insulation. Settings will control what to use for
    # each column

    my $dg = &get_insulation_subtype($hh,
				     $settings,
				     'glazing',
				     $dg_probs,
				     $rinsulation,
				     $rinsulation_file,
				     $survey_file);

    my $loft = &get_insulation_subtype($hh,
				       $settings,
				       'loft',
				       $loft_probs,
				       $rinsulation,
				       $rinsulation_file,
				       $survey_file);

    my $wall = &get_insulation_subtype($hh,
				       $settings,
				       'wall',
				       $wall_probs,
				       $rinsulation,
				       $rinsulation_file,
				       $survey_file);

    my $insulation = $$settings{'minimum'};
    if($dg ne "-1") {
      $insulation = $dg;
    }
    if($loft ne "-1") {
      $insulation = ($insulation eq $$settings{'minimum'}
		     ? $loft
		     : $insulation."-$loft");
    }
    if($wall ne "-1") {
      $insulation = ($insulation eq $$settings{'minimum'}
		     ? $wall
		     : $insulation."-$wall");
    }

    # Check the insulation is valid for this type of dwelling

    if(!defined($insn->{$dw_type})) {
      die "Dwelling type \"$dw_type\" of dwelling ID $dwelling_id is not ",
	"defined in insulation file $insn_file\n";
    }
    elsif(!defined($insn->{$dw_type}->{$insulation})) {
      my @valid_ins = keys(%{$insn->{$dw_type}});

      my @choice_set;
      my $choice_set_similarity;

      foreach my $ins_type (@valid_ins) {
	my @sub_ins = @{$insn_states->{$ins_type}};

	my $similarity = 0;
	$similarity++ if($dg eq $sub_ins[0]);
	$similarity++ if($loft eq $sub_ins[1]);
	$similarity++ if($wall eq $sub_ins[2]);

	if(scalar(@choice_set) == 0) {
	  push(@choice_set, $ins_type);
	  $choice_set_similarity = $similarity;
	}
	elsif($choice_set_similarity == $similarity) {
	  push(@choice_set, $ins_type);
	}
	elsif($similarity < $choice_set_similarity) {
	  @choice_set = ($ins_type);
	  $choice_set_similarity = $similarity;
	}
      }

      if(scalar(@choice_set) == 0) {
	die "Retrodicted insulation state $insulation is not a valid entry for",
	  " a dwelling of type $dw_type, but somehow there are none to choose ",
	  "from. (Similarity is $choice_set_similarity; valid set is ",
	  join(", ", @valid_ins), ") This is a sort of 'panic' because the ",
	  "foregoing code should not allow the situation to occur.\n";
      }
      elsif(scalar(@choice_set) > 1) {
	warn "Retrodicted insulation state $insulation is not a valid entry ",
	  "for a dwelling of type $dw_type, and there is a choice of \"",
	  join("\", \"", @choice_set), "\" insulation states to use in its ",
	  "place. Ideally, there would only be one option. A random selection ",
	  "will be made.\n";
      }

      $insulation = $choice_set[int(rand(scalar(@choice_set)))];
    }

    # Add the chosen insulation state to the dwellings file

    print FP ",$insulation\n";
  }
  
  close(FP);
}

# get_insulation_subtype
#
# Return the insulation subtype for this household in 2000 given the
# insulation state in 2010 in the survey file and the insulation retrodiction
# data.

sub get_insulation_subtype {
  my ($hh, $settings, $key, $probs, $rinsulation, $rinsulation_file,
      $survey_file) = @_;

  my @in = split(/,/, $$settings{$key});
  my @in_entry = split(/,/, $$settings{$key.'-entry'});
  my $which_in = -1;
  for(my $i = 0; $i <= $#in; $i++) {
    next if $$hh{$in[$i]} eq "";
    if(!defined($$hh{$in[$i]})) {
      die "Cannot determine insulation subtype $in_entry[$i] in survey file ",
	"$survey_file using column identifier $in[$i] (check setting $key)\n";
    }
    if($$hh{$in[$i]} eq $$settings{'has-insulation'}) {
      if($which_in < 0) {
	$which_in = $i;
      }
      else {
	die "Error in household file $survey_file for household with ID ",
	  "$$hh{$$settings{'ID'}}: entry $$settings{'has-insulation'} ",
	  "indicating presence of two mutually exclusive insulation subtypes ",
	  "$in_entry[$which_in] (column $in[$which_in]) and $in_entry[$i] ",
	  "(column $in[$i]). Check settings for \'$key\'\n";
      }
    }
  }

  if($which_in >= 0) {
    if(!defined($$rinsulation{$in_entry[$which_in]})) {
      die "Error in insulation retrodiction file $rinsulation_file: no ",
	"information provided for insulation subtype ",
	"$in_entry[$which_in] which household $$hh{$$settings{'ID'}} has\n";
    }
    my $prob_sample = shift(@$probs);
    if($prob_sample < $rinsulation->{$in_entry[$which_in]}->[0]) {
      $in_entry[$which_in] = $rinsulation->{$in_entry[$which_in]}->[1];
    }
    else {
      $which_in = -1;
    }
  }

  return $which_in == -1 ? "-1" : $in_entry[$which_in];
}

# write_initial_appliances
#
# Write the initial appliances using the survey file, the pre-initial
# appliances file and the appliances retrodiction file

sub write_initial_appliances {
  my ($file, $settings, $survey, $survey_file, $appliances, $appliances_file,
      $rappliances, $rappliances_file, $boiler_probs, $dishwasher_probs,
      $dryer_probs) = @_;

  open(FP, ">", $file)
    or die "Cannot create initial appliances file $file: $!\n";

  foreach my $hh (@$survey) {
    my $hh_ID = $$hh{$$settings{'ID'}};

    print FP "$$settings{'hh'}$hh_ID";

    # That's the easy part over! Now to determine the appliance subcategories

    my @apps = split(/,/, $$settings{'assign-all'});

    # Heating 

    if(!defined($$hh{$$settings{'electric-fuel'}})) {
      die "Cannot determine electric primary fuel type for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'electric-fuel'} (check setting \'electric-fuel\')\n";
    }
    if(!defined($$hh{$$settings{'gas-fuel'}})) {
      die "Cannot determine gas primary fuel type for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'gas-fuel'} (check setting \'gas-fuel\')\n";
    }
    if(!defined($$hh{$$settings{'oil-fuel'}})) {
      die "Cannot determine oil primary fuel type for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'oil-fuel'} (check setting \'oil-fuel\')\n";
    }
    if($$hh{$$settings{'electric-fuel'}} == $$settings{'has-X-n'}) {
      push(@apps, $$settings{'electric-heating'});
    }
    elsif($$hh{$$settings{'gas-fuel'}} == $$settings{'has-X-n'}) {
      if(!defined($$hh{$$settings{'gas-boiler-condensing'}})) {
	die "Cannot determine if gas boiler is condensing for household ",
	  "$hh_ID in survey file $survey_file using column identifier ",
	  "$$settings{'gas-boiler-condensing'} (check setting ",
	  "\'gas-boiler-condensing\')\n";
      }
      if($$hh{$$settings{'gas-boiler-condensing'}} == $$settings{'has-X-n'}
	 && shift(@$boiler_probs) < $$settings{'p-condensing'}) {
	push(@apps, $$settings{'gas-conboiler-sub'});
      }
      else {
	push(@apps, $$settings{'gas-boiler-sub'});
      }
    }
    elsif($$hh{$$settings{'oil-fuel'}} == $$settings{'has-X-n'}) {
      if(!defined($$hh{$$settings{'oil-boiler-condensing'}})) {
	die "Cannot determine if oil boiler is condensing for household ",
	  "$hh_ID in survey file $survey_file using column identifier ",
	  "$$settings{'oil-boiler-condensing'} (check setting ",
	  "\'oil-boiler-condensing\')\n";
      }
      if($$hh{$$settings{'oil-boiler-condensing'}} == $$settings{'has-X-n'}
	 && shift(@$boiler_probs) < $$settings{'p-condensing'}) {
	push(@apps, $$settings{'oil-conboiler-sub'});
      }
      else {
	push(@apps, $$settings{'oil-boiler-sub'});
      }
    }
    else {
      die "Household $hh_ID does not have any primary fuel as identified by ",
	"a value of 1 in columns $$settings{'gas-fuel'} (gas), ",
	"$$settings{'electric-fuel'} (electricity) or $$settings{'oil-fuel'} ",
	"(oil) in survey file $survey_file (check settings \'gas-fuel\'",
	"\'electric-fuel\' and \'oil-fuel\')\n";
    }

    # Cooker

    if(!defined($$hh{$$settings{'hob-type'}})) {
      die "Cannot determine hob type for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'hob-type'} (check setting \'hob-type\')\n";
    }
    if($$hh{$$settings{'hob-type'}}
       == $$settings{'hob-type-gas-or-dual'}) {
      if(!defined($$hh{$$settings{'oven-type'}})) {
	die "Cannot determine oven type for household $hh_ID ",
	  "in survey file $survey_file using column identifier ",
	  "$$settings{'oven-type'} (check setting \'oven-type\')\n";
      }
      if($$hh{$$settings{'oven-type'}} == $$settings{'oven-type-gas'}) {
	push(@apps, $$settings{'gas-cooker-sub'});
      }
      else {
	push(@apps, $$settings{'dual-fuel-cooker-sub'});
      }
    }
    elsif($$hh{$$settings{'hob-type'}}
	  == $$settings{'hob-type-electric'}) {
      push(@apps, $$settings{'electric-cooker-sub'});
    }
    elsif($$hh{$$settings{'hob-type'}}
	  == $$settings{'hob-type-chob'}) {
      push(@apps, $$settings{'chob-cooker-sub'});
    }
    else {
      die "Cannot allocate any type of cooker for household $hh_ID in survey ",
	"file $survey_file as column identifier $$settings{'hob-type'} is not ",
	"one of $$settings{'hob-type-gas-or-dual'}, ",
	"$$settings{'hob-type-electric'}, or $$settings{'hob-type-chob'} ",
	"(check settings \'hob-type\', \'hob-type-gas-or-dual\', ",
	"\'hob-type-electric\' and \'hob-type-chob\' respectively)\n";
    }

    # Fridge

    if(!defined($$hh{$$settings{'n-fridge-freezer'}})) {
      die "Cannot determine number of fridge freezers for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'n-fridge-freezer'} (check setting ",
	"\'n-fridge-freezer\')\n";
    }
    if($$hh{$$settings{'n-fridge-freezer'}} > 0) {
      push(@apps, $$settings{'fridge-freezer-sub'});
    }
    else {
      push(@apps, $$settings{'fridge-sub'});
    }
  
    # Freezer

    if(!defined($$hh{$$settings{'n-freezer'}})) {
      die "Cannot determine number of freezers for household $hh_ID ",
	"in survey file $survey_file using column identifier ",
	"$$settings{'n-freezer'} (check setting \'n-freezer\')\n";
    }
    if($$hh{$$settings{'n-freezer'}} > 0) {
      push(@apps, $$settings{'freezer-sub'});
    }

    # Dishwasher

    &retrodict_appliance($hh,
			 $settings,
			 'dishwasher',
			 $$settings{'dishwasher-threshold'},
			 'dishwasher-sub',
			 "dishwasher",
			 $rappliances,
			 $dishwasher_probs,
			 $survey_file,
			 $rappliances_file,
			 \@apps);

    # Tumble dryer

    &retrodict_appliance($hh,
			 $settings,
			 'dryer',
			 $$settings{'dryer-threshold'},
			 'dryer-sub',
			 "tumble dryer",
			 $rappliances,
			 $dryer_probs,
			 $survey_file,
			 $rappliances_file,
			 \@apps);

    # Choose the actual appliances

    my @choices = &choose_appliances(\@apps, $appliances, $appliances_file,
				     $settings);

    print FP ",", join(",", @choices), "\n";
  }
  
  close(FP);

  &warn_unused_retrodictions($rappliances, $rappliances_file);
}

# retrodiction of appliances
#
# Keep track of appliances that have been retrodicted, so we can warn about
# which appliance subcategories in the appliances retrodiction file have
# not been used

{
  my %used_appliance_retrodictions;
				# Appliance retrodiction subcategories
				# that have been used

  # retrodict_appliance
  #
  # Retrodict a particular appliance, pushing the subcategory on to the
  # apps array
  
  sub retrodict_appliance {
    my ($hh, $settings, $column_id, $threshold, $subcat, $appliance_str,
	$rappliances, $probs, $survey_file, $rappliances_file, $apps) = @_;

    if(!defined($$hh{$$settings{$column_id}})) {
      die "Cannot determine whether household $$hh{$$settings{'ID'}} has ",
	"a(n) $appliance_str in survey file $survey_file using column ",
	"identifier $$settings{$column_id} (check setting \'$column_id\')\n";
    }
    if($$hh{$$settings{$column_id}} > $threshold) {
      if(!defined($$rappliances{$$settings{$subcat}})) {
	die "Error in appliances retrodiction file $rappliances_file: cannot ",
	  "find an entry for $$settings{$subcat} from setting \'$subcat\' ",
	  "(check setting \'$column_id\' as well)\n";
      }
      if(shift(@$probs)
	 < $$rappliances{$$settings{$subcat}}) {
	push(@$apps, $$settings{$subcat});
      }
    }

    $used_appliance_retrodictions{$$settings{$subcat}} = 1;

  }

  # warn_unused_retrodictions
  #
  # Check all the subcategories that have been retrodicted and issue warnings
  # for any in the appliances retrodiction file that haven't been used.

  sub warn_unused_retrodictions {
    my ($rappliances, $rappliances_file) = @_;

    foreach my $key (sort(keys(%$rappliances))) {
      if(!defined($used_appliance_retrodictions{$key})) {
	warn "WARNING: appliance retrodiction subcategory $key specified ",
	  "in appliances retrodiction file $rappliances_file is not used\n";
      }
    }
  }
}

# choose_appliances
#
# Select appliances using the appliances file from a list of appliance
# subcategories

sub choose_appliances {
  my ($subcats, $appliances, $appliances_file, $settings) = @_;

  if(!defined($appliances->[0]->{$$settings{'appliance-1st-step'}})) {
    die "Error in appliances file $appliances_file: Cannot determine first ",
      "step available from column identifier ",
      "$$settings{'appliance-1st-step'} ",
      "(check setting \'appliance-1st-step\')\n";
  }
  if(!defined($appliances->[0]->{$$settings{'appliance-name'}})) {
    die "Error in appliances file $appliances_file: Cannot determine ",
      "appliance name from column identifier ",
      "$$settings{'appliance-name'} ",
      "(check setting \'appliance-name\')\n";
  }
  if(!defined($appliances->[0]->{$$settings{'appliance-subcategory'}})) {
    die "Error in appliances file $appliances_file: Cannot determine ",
      "appliance subcategory from column identifier ",
      "$$settings{'appliance-subcategory'} ",
      "(check setting \'appliance-subcategory\')\n";
  }
  
  my $available = &select_query("$$settings{'appliance-1st-step'} NEQ 0",
				$appliances);

  my %lookup;
  foreach my $appliance (@$available) {
    push(@{$lookup{$$appliance{$$settings{'appliance-subcategory'}}}},
	 $$appliance{$$settings{'appliance-name'}});
  }
  
  my @choices;

  foreach my $subcat (@$subcats) {
    if(defined($lookup{$subcat})) {
      my @options = @{$lookup{$subcat}};
      my $selection = int(rand(scalar(@options)));
      push(@choices, $options[$selection]);
    }
    else {
      foreach my $setting_key (keys(%$settings)) {
	if($$settings{$setting_key} eq $subcat) {
	  die "Error in appliances file $appliances_file: Cannot find ",
	    "appliance with subcategory $subcat (check setting ",
	    "$setting_key)\n";
	}
      }
      die "Error in appliances file $appliances_file: Cannot find ",
	"appliance with subcategory $subcat (and cannot determine the source ",
	"of this subcategory -- no settings have it as a value)\n";
    }
  }
  return @choices;
}

# write_xml
#
# Write an XML describing this experiment using the setup. Also copy across
# any files we can find that are known to be part of the setup into the
# experiment directory

sub write_xml {
  my ($file, $setup_ID, $setup, $string_param, $script_param, $nlogo) = @_;

  my @files;			# Files to be copied to the setup
                                # directory, because they are in the
                                # netlogo file if it is given, or if
                                # it is not given, because they are
                                # known to be files based on them
                                # being string parameters ending in
                                # '-file' that the user has specified
                                # on the command line
  my $copied_nlogo = "";
  
  if(defined($nlogo)) {		# The netlogo file was given
    my $param = &parse_nlogo_gui_params($nlogo);

    foreach my $param_var (keys(%$param)) {
      if($param_var =~ /-file$/ && $param->{$param_var}->[0] eq 'INPUTBOX'
	 && $param->{$param_var}->[3] eq "String"
	 && $param->{$param_var}->[2] ne "null"
	 && !defined($$setup{$param_var})) {
	push(@files, $param->{$param_var}->[2]);
      }
      if($param->{$param_var}->[0] eq 'INPUTBOX'
	 && $param->{$param_var}->[3] =~ /^String/
	 && !defined($$string_param{$param_var})) {
	$$string_param{$param_var} = 1;
      }
      # This next bit isn't really needed, because CEDSS doesn't have any
      # choosers of strings. I've just put it here to remind myself if
      # I decide to reuse this code for another model that does have string
      # choosers.
      if($param->{$param_var}->[0] eq 'CHOOSER'
	 && $param->{$param_var}->[3] =~ /\"/
	 && !defined($$string_param{$param_var})) {
	$$string_param{$param_var} = 1;
      }
    }

    my $cp_nlogo = 1;
    foreach my $setup_var (keys(%$setup)) {
      next if $setup_var eq "nsteps";
      next if $setup_var eq "output-file";
      if(!defined($$param{$setup_var})
	 && !defined($$script_param{$setup_var})) {
	warn "NetLogo file $nlogo does not have a parameter named $setup_var,",
	  " which you have requested to be $$setup{$setup_var}. The XML file ",
	  "will be written, but the NetLogo file won't be copied\n";
	$cp_nlogo = 0;
      }
    }

    if($cp_nlogo) {
      my $dest_nlogo = $nlogo;
      if($dest_nlogo =~ /\//) {
	my @path = split(/\//, $nlogo);
	$dest_nlogo = $path[$#path];
      }
      &cp($nlogo, "$setup_ID/$dest_nlogo", $use_links);
      $copied_nlogo = $dest_nlogo;
    }
  }

  # Add setup parameters that the user has specified on the command line to
  # the list of files to load, where they are known (or reasonably expected)
  # to be files.

  my %file2param;

  foreach my $param (keys(%$string_param)) {
    if($param =~ /-file$/ && defined($$setup{$param})
       && !defined($$script_param{$param}) && $$setup{$param} ne "null") {
      push(@files, $$setup{$param});
      $file2param{$$setup{$param}} = $param;
    }
  }

  # Loop through the files and try to find them and copy them to the experiment
  # directory

  foreach my $file (@files) {
    if(-f "$file") {		# The user-requested setup file exists...
      my $dest_file = $file;
      if($file =~ /\//) {	# ...if it's in another directory,
                                # strip off the path to put it in the
                                # destination
	my @path = split(/\//, $file);
	$dest_file = $path[$#path];
      }
      &cp($file, "$setup_ID/$dest_file", $use_links);
      if(defined($file2param{$file})) {
	$$setup{$file2param{$file}} = $dest_file;
      }
    }
    elsif(defined($nlogo) && $nlogo =~ /\//) {
				# The user-requested setup file does
                                # not exist, but they've given a
                                # netlogo location in another
                                # directory -- try looking there
      my @path = split(/\//, $nlogo);
      $path[$#path] = $file;

      my $src_file = join("/", @path);

      if(-f "$src_file") {
	&cp($src_file, "$setup_ID/$file", $use_links);
      }
      else {
	warn "Could not copy file $file to the experimental setup ",
	  "directory $setup_ID because it couldn't be found either in ",
	  "the current working directory or at $src_file, in the same ",
	  "directory as the NetLogo model $nlogo\n";
      }
    }
    else {
      warn "Could not find file $file to copy it to the experimental setup ",
	"directory $setup_ID\n";
    }
  }
  
  open(FP, ">", $file)
    or die "Cannot create experimental setup file $file: $!\n";

  print FP <<XML_END;
<?xml version="1.0" encoding="us-ascii"?>
<!DOCTYPE experiments SYSTEM "behaviorspace.dtd">
<experiments>
  <experiment name="$setup_ID" repetitions="1" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <final>export-all-plots &quot;$$setup{'output-file'}&quot;</final>
    <timeLimit steps="$$setup{'nsteps'}"/>
XML_END

  foreach my $setup_key (sort(keys(%$setup))) {
    next if $setup_key eq 'output-file';
    next if $setup_key eq 'nsteps';
    print FP "    <enumeratedValueSet variable=\"$setup_key\">\n";
    if(defined($$string_param{$setup_key})) {
      print FP "      <value value=\"&quot;$$setup{$setup_key}&quot;\"/>\n";
    }
    else {
      print FP "      <value value=\"$$setup{$setup_key}\"/>\n";
    }
    print FP "    </enumeratedValueSet>\n";
  }

  print FP "  </experiment>\n</experiments>\n";

  close(FP);

  return $copied_nlogo;
}

# write_sh
#
# Write a shell script to run the model with a given run ID

sub write_sh {
  my ($file, $xml, $java, $model, $experiment, $netlogo) = @_;

  open(FP, ">", $file) or die "Cannot create shell script file $file: $!\n";

  print FP "#!/bin/sh\n";
  print FP "mem=\$1\n";
  print FP "run=\$2\n";
  print FP "xml=`echo \"$xml\" | sed -e \"s/\\.xml\$/-\$run.xml/\"`\n";
  print FP "out=`echo \"\$xml\" | sed -e \"s/\\.xml\$/.out/\"`\n";
  print FP "err=`echo \"\$xml\" | sed -e \"s/\\.xml\$/.err/\"`\n";
  print FP "wd=`pwd`\n";
  print FP "cat \"$xml\" | sed -e \"s/-output\\.csv/-output-\$run.csv/\" > ",
    "\$xml\n";
  print FP "cd \"$netlogo\"\n";
  print FP "$java -XX:ParallelGCThreads=1 -Xmx\$mem -Dfile.encoding=UTF-8 ",
    "-cp NetLogo.jar org.nlogo.headless.Main --threads 1 ",
    "--model \"\$wd/$model\" --setup-file \"\$wd/\$xml\" ",
    "--experiment \"$experiment\" > \"\$wd/\$out\" 2> \"\$wd/\$err\"\n";
  
  close(FP);

  chmod(0755, $file) or die "Cannot make shell script file $file ",
    "executable: $!\n";
}

# write_config
#
# Write configuration of the run

sub write_config {
  my ($file, $args, $setup, $settings) = @_;

  open(FP, ">", $file) or die "Cannot create config file $file: $!\n";

  print FP "ARG,", join(",", @$args), "\n";
  print FP "SETTINGS";
  foreach my $key (keys(%$settings)) {
    print FP ",$key=$$settings{$key}";
  }
  print FP "\nSETUP";
  foreach my $key (keys(%$setup)) {
    print FP ",$key=$$setup{$key}";
  }
  print FP "\n";

  close(FP);
}

##############################################################################
# Reading files subroutines
#
# Patch file: read_patches(filename) ==> {x}->{y}->entry
#
# Survey info file: read_database(filename) ==> [{field}->value, ...]
#
# Income file: read_incomes(filename) ==> {band}->{tenancy}->[income, ...]
#
# Capital file: read_capital(filename, income data, income file)
#              ==> {band}->{tenancy}->[[cumulative probability, cabital], ...]
#
# Pre-dwellings file: read_dwellings(filename) ==> {id}->[id, tenure, type]
#
# Insulation retrodiction file: read_insulation_retrodiction(filename)
#              ==> {2010 sub-state}->[prob, 2000 sub-state]
#
# Appliances file: read_database(filename) ==> [{field}->value, ...]
#
# Appliances retrodiction file: read_appliance_retrodiction(filename)
#              ==> {subcategory}->prob
#
##############################################################################

# read_patches ==> {x}->{y}->entry
#
# Subroutine to read in a raster CSV format patch file in which the first
# row contains the x co-ordinates (which must increase by 1 from the second
# column) starting in the second column, and the first column (except on the
# first row) contains the y-co-ordinates (which are expected to decrease by 1
# starting from the second row. The entries are the values S for stree, P for
# park, J for junction, E for empty, or a number giving the numerical part
# of the dwelling name if the patch is a dwelling.

sub read_patches {
  my ($file) = @_;

  open(FP, "<", $file)
    or die "Cannot open patch raster CSV file $file for reading: $!\n";

  my $header = <FP>;
  $header =~ s/\s+$//;
  my @xs = split(/,/, $header);
  shift(@xs);			# Remove first column
  if($xs[0] != 0) {
    warn "WARNING: The first x co-ordinate is not 0 ($xs[0])\n";
  }
  for(my $i = 1; $i <= $#xs; $i++) {
    if($xs[$i] != $xs[$i - 1] + 1) {
      die "Error in patch raster CSV file $file: the ", $i + 1, "th x ",
	"co-ordinate ($xs[$i]) is not one more than the ", $i, "th ",
	"($xs[$i - 1])\n";
    }
  }

  my %data;

  my @ys;
  my $line_no = 1;
  while(my $line = <FP>) {
    $line =~ s/\s+$//;
    $line_no++;
    
    my ($y, @cells) = split(/,/, $line);

    if(scalar(@ys) > 0) {
      if($y != $ys[$#ys] - 1) {
	die "Error in patch raster CSV file $file, line $line_no: the y ",
	  "co-ordinate in the first column ($y) is not one less than that on ",
	  "the previous line ($ys[$#ys])\n";
      }
    }
    push(@ys, $y);

    if(scalar(@cells) != scalar(@xs)) {
      if(scalar(@cells) > scalar(@xs)) {
	warn "WARNING in patch raster CSV file $file, line $line_no: the ",
	  "number of columns for the x co-ordinate entries (", scalar(@cells),
	  ") is more than that on the first line (", scalar(@xs), ")\n";
      }
      else {
	die "Error in patch raster CSV file $file, line $line_no: the number ",
	  "of columns for the x co-ordinate entries (", scalar(@cells),
	  ") is less than that on the first line (", scalar(@xs), ")\n";
      }
    }

    for(my $i = 0; $i <= $#xs; $i++) {
      $cells[$i] =~ s/\s//g;	# Remove white space, which might have been
				# used to align columns in fixed width fonts
      $data{$xs[$i]}->{$y} = $cells[$i];
    }
  }
  
  if($ys[$#ys] != 0) {
    warn "WARNING: The lowest y co-ordinate is not 0 ($ys[$#ys])\n";
  }

  close(FP);

  return \%data;
}

# read_database ==> [{field}->value, ...]
#
# Subroutine to read a database file. This is a CSV format with one row per
# entry, and what are expected to be unique column names representing fields.
# The return value is an array of hash of column name to value with one element
# in each row for each entry in the database. Empty cells are given the value
# NA.

sub read_database {
  my ($file) = @_;

  open(FP, "<", $file) or die "Cannot open database file $file: $!\n";

  my $header = <FP>;
  $header =~ s/\s+$//;
  
  my @fields = split(/,/, $header);
  
  my @db;

  my $line_no = 1;
  while(my $line = <FP>) { 
    $line_no++;

    $line =~ s/\s+$//;

    my @cells = split(/,/, $line);

    if(scalar(@cells) != scalar(@fields)) {
      if(scalar(@cells) > scalar(@fields)) {
	warn "Warning in database file $file, line $line_no: there are ",
	  scalar(@cells), " cells on this line, but only ", scalar(@fields),
	  " fields on the first line -- extra cells will be ignored\n";
      }
      else {
	die "Error in database file $file, line $line_no: there are ",
	  scalar(@cells), " cells on this line, which is not enough to ",
	  "populate the ", scalar(@fields), " fields on the first line\n";
      }
    }

    my %entry;

    for(my $i = 0; $i <= $#fields; $i++) {
      if($cells[$i] eq "" or !defined($cells[$i])) {
	$cells[$i] = "NA";
      }

      $entry{$fields[$i]} = $cells[$i];

      # Allow access to fields by Excel-style column label; this means it
      # is not a problem if field names are duplicated. (It is a problem if
      # field names intersect with column labels.)
      if($i <= ord("Z") - ord("A")) {
	$entry{chr(ord("A") + $i)} = $cells[$i];
      }
      else {
	my $n = 1 + ord("Z") - ord("A");
	my $j = int($i / $n) - 1;
	my $k = $i % $n;

	$entry{chr(ord("A") + $j).chr(ord("A") + $k)} = $cells[$i];
      }
    }

    push(@db, \%entry);
  }

  close(FP);

  return \@db;
}

# read_incomes ==> {band}->{tenancy}->[income, ...]
#
# Read the income band file, which specifies, for each income band and tenancy
# the income per year. The data will be returned as a hash of income band and
# tenancy to array of incomes

sub read_incomes {
  my ($file) = @_;

  open(FP, "<", $file)
    or die "Cannot open income file $file for reading: $!\n";

  my $bandline = <FP>;
  $bandline =~ s/\s+$//;
  my @bands = split(/,/, $bandline);

  my $tenancyline = <FP>;
  $tenancyline =~ s/\s+$//;
  my @tenancies = split(/,/, $tenancyline);

  if(scalar(@tenancies) != scalar(@bands)) {
    die "Income file $file is expected to have two header rows with an equal ",
      "number of columns. In your file, the first row has ", scalar(@bands),
      "columns; the second has ", scalar(@tenancies), " columns\n";
  }

  my %data;

  my $line_no = 2;
  while(my $line = <FP>) {
    $line_no++;
    $line =~ s/\s+$//;
    my @cells = split(/,/, $line);

    if(scalar(@cells) != scalar(@bands)) {
      if(scalar(@cells) > scalar(@bands)) {
	warn "Warning in income file $file, line $line_no: there are ",
	  scalar(@cells), " columns, where based on the headers, ",
	  scalar(@bands), " columns are expected. Extra columns on this line ",
	  "will be ignored.\n";
      }
      else {
	die "Error in income file $file, line $line_no: there are ",
	  scalar(@cells), " columns, where based on the headers, ",
	  scalar(@bands), " columns are expected.\n";
      }
    }

    for(my $i = 0; $i <= $#bands; $i++) {
      push(@{$data{$bands[$i]}->{$tenancies[$i]}}, $cells[$i]);
    }
  }

  close(FP);

  return \%data;
}

# read_capital ==> {band}->{tenancy}->[[cum. prob, capital], ...]
#
# Read the capital file. This has a similar format to the income file (hence
# the rather uncomfortably large amount of duplicated code), but here the rows
# alternate between specifying a (cumulative) probability and a capital
# associated with the probability on the previous line. Flexibility is provided
# to allow the bands to have distributions of different lengths.
#
# The number of bands of must match those of the income file

sub read_capital {
  my ($file, $income_data, $income_file) = @_;
				# Note that $income_data and
				# $income_file are optional
  open(FP, "<", $file)
    or die "Cannot open capital file $file for reading: $!\n";

  my $bandline = <FP>;
  $bandline =~ s/\s+$//;
  my @bands = split(/,/, $bandline);

  if(defined($income_data)) {	# Check the income and capital bands match
    my @income_bands = sort(keys(%$income_data));

    my %capital_bands;
    foreach my $band (@bands) {
      $capital_bands{$band} = 1;
    }
    my @sorted_bands = sort(keys(%capital_bands));

    if(scalar(@income_bands) != scalar(@sorted_bands)) {
      die "Capital file $file has a different number of bands (",
	scalar(@income_bands),") than is ",
	"specified in ", (defined($income_file)
			  ? "income file $income_file"
			  : "the income file"),
			    " (", scalar(@sorted_bands), ").\n";
    }

    for(my $i = 0; $i <= $#income_bands; $i++) {
      if($income_bands[$i] ne $sorted_bands[$i]) {
	print STDERR ("Different labels for income and capital bands ",
		      "specified in capital file $file and ",
		      (defined($income_file)
		       ? "income file $income_file"
		       : "the income file"),
		      ": the ", $i + 1, " sorted label is $sorted_bands[$i] ",
		      "in the capital file, but $income_bands[$i] in the ",
		      "income file\n");
	for(my $j = 0; $j <= $#income_bands; $j++) {
	  print STDERR ("\tBand $j (in sort order): capital label ",
			"\"$sorted_bands[$j]\" ",
			($sorted_bands[$j] eq $income_bands[$j] ? "==" : "!="),
			" income label \"$income_bands[$j]\"\n");
	}
	die "Band labels must match\n";
      }
    }
  }

  my $tenancyline = <FP>;
  $tenancyline =~ s/\s+$//;
  my @tenancies = split(/,/, $tenancyline);

  if(scalar(@tenancies) != scalar(@bands)) {
    die "Capital file $file is expected to have two header rows with an equal",
      " number of columns. In your file, the first row has ", scalar(@bands),
      "columns; the second has ", scalar(@tenancies), " columns\n";
  }

  my %data;

  my $line_no = 2;
  my @probs;
  my @capitals;
  my @ignore_columns;
  for(my $i = 0; $i <= $#bands; $i++) {
    $ignore_columns[$i] = 0;
  }
  my $prob_line = 0;
  while(my $line = <FP>) {
    $line_no++;
    $line =~ s/\s+$//;
    
    my @cells = split(/,/, $line);

    if(scalar(@cells) != scalar(@bands)) {
      if(scalar(@cells) > scalar(@bands)) {
	warn "Warning in capital file $file, line $line_no: there are ",
	  scalar(@cells), " columns, where based on the headers, ",
	  scalar(@bands), " columns are expected. Extra columns on this line ",
	  "will be ignored.\n";
      }
      else {
	die "Error in capital file $file, line $line_no: there are ",
	  scalar(@cells), " columns, where based on the headers, ",
	  scalar(@bands), " columns are expected.\n";
      }
    }

    if($line_no == 3) {		# Line of 0s optional
      if($line eq "0".(",0" x $#bands)) {
	$prob_line = 1;
	next;
      }
    }
    
    if($line_no % 2 == $prob_line) {
				# 'Prob' numbered line: probabilities
				# Use these to assign capitals from
				# the previous line
      for(my $i = 0; $i <= $#bands; $i++) {
	if($line_no > 3 && $cells[$i] <= $probs[$i]) {
	  die "Error in capital file $file, line $line_no, column ", $i + 1,
	    ": cumulative probability $cells[$i] is not strictly greater ",
	    "than that specified on line ", $line_no - 2, " ($probs[$i])\n";
	}
	if(!$ignore_columns[$i]) {
	  if($cells[$i] < 0 || $cells[$i] > 1) {
	    die "Error in capital file $file, line $line_no, column ", $i + 1,
	      ": entry \"$cells[$i]\" is outside the range [0, 1]\n";
	  }
	  $probs[$i] = $cells[$i];
	  push(@{$data{$bands[$i]}->{$tenancies[$i]}},
	       [$probs[$i], $capitals[$i]]);
	}
	if($cells[$i] == 1) {
	  $ignore_columns[$i] = 1;
	}
      }
    }
    else {			# 'Not prob' numbered line: capitals
      for(my $i = 0; $i <= $#bands; $i++) {
	if($line_no > 4 && $cells[$i] <= $capitals[$i]) {
	  die "Error in capital file $file, line $line_no, column ", $i + 1,
	    ": capital $cells[$i] is not strictly greater than that specified",
	    " on line ", $line_no - 2, "($capitals[$i]\n";
	}
	if(!$ignore_columns[$i]) {
	  if($cells[$i] !~ /^[+-]?\d+$/) {
	    die "Error in capital file $file, line $line_no, column ", $i + 1,
	      ": capital $cells[$i] is not an integer expressed as a sequence",
	      " of digits\n";
	  }
	  $capitals[$i] = $cells[$i];
	}
      }
    }
  }

  close(FP);

  return \%data;
}

# read_dwellings ==> {id}->[id, tenure, type]
#
# Read the dwellings file

sub read_dwellings {
  my ($file, $settings) = @_;

  open(FP, "<", $file)
    or die "Cannot open pre-dwellings file $file for reading: $!\n";

  my $headerline = <FP>;
  $headerline =~ s/\s+$//;
  if($headerline ne "id,tenure,type") {
    die "First row of dwellings file expected to be \"id,tenure,type\"; it is",
      "instead \"$headerline\"\n";
  }

  my %data;

  while(my $line = <FP>) {
    $line =~ s/\s+$//;

    my ($id, $tenure, $type) = split(/,/, $line);
    
    $id =~ s/^$$settings{'dw'}//; # Remove dw prefix from dwelling ID for now

    $data{$id} = [$id, $tenure, $type];
  }

  close(FP);

  return \%data;
}

# read_insulation ==> {type}->{state}->factor
#
# Read the insulation file; check all the different insulation states.

sub read_insulation {
  my ($file, $settings) = @_;

  open(FP, "<", $file) or die "Cannot read insulation file $file: $!\n";

  my %data;
  my %states;

  my $header = <FP>;
  $header =~ s/\s+$//;

  if($header ne "insulation-state,fuel-use-factor,dwelling-type") {
    die "Insulation file must have \"insulation-state,fuel-use-factor,",
      "dwelling-type\" as its first line, instead of \"$header\"\n";
  }

  while(my $line = <FP>) {
    $line =~ s/\s+$//;
    my ($state, $factor, $type) = split(/,/, $line);
    $data{$type}->{$state} = $factor;

    if(!defined($states{$state})) {
      my @parts = split(/-/, $state);
      $states{$state} = \@parts;
    }
  }
  
  close(FP);

  # Now try to get all the parts. Use the 3-part states to get all the options
  # for the others

  my @partarr;
  my $nparts = 0;

  foreach my $state (keys(%states)) {
    my @parts = @{$states{$state}};
    if(scalar(@parts) > $nparts) {
      @partarr = ();
      $nparts = scalar(@parts);
    }
    # Get all the parts of the states with the most number of specified parts
    if(scalar(@parts) == $nparts) {
      for(my $i = 0; $i <= $#parts; $i++) {
	$partarr[$i]->{$parts[$i]} = 1;
      }
    }
  }

  # Having got all the parts, we can now split up all the states

  foreach my $state (keys(%states)) {
    my @parts = @{$states{$state}};
    my @fullparts;

    my $j;
    for(my $i = 0, $j = 0; $i <= $#partarr; $i++) {
      if($j <= $#parts && defined($partarr[$i]->{$parts[$j]})) {
	$fullparts[$i] = $parts[$j];
	$j++;
      }
      else {
	$fullparts[$i] = -1;
      }
    }

    if($j <= $#parts && $state ne $$settings{'minimum'}) {
      die "Error in insulation file $file: Insulation state $state contains ",
	"part string $parts[$j] that does not appear in one of the 'full' ",
	"insulation states with $nparts parts (each part being separated by ",
	"a '-')\n";
    }

    $states{$state} = \@fullparts;
  }

  return (\%data, \%states);
}

# read_insulation_retrodiction ==> {2010 sub-state}->[prob, 2000 sub-state]
#
# Read the insulation state. Note that if two insulation states start with
# the same substring that is longer than 1 character, they are assumed to be
# mutually exclusive.

sub read_insulation_retrodiction {
  my ($file) = @_;

  open(FP, "<", $file)
    or die "Cannot open insulation retrodiction file $file for reading: $!\n";

  my $substate2010line = <FP>;
  $substate2010line =~ s/\s+$//;
  my @substate2010 = split(/,/, $substate2010line);

  if(scalar(@substate2010) == 0) {
    die "No insulation sub-states for 2010 are specified on the first line ",
      "of the insulation retrodiction file $file\n";
  }

  my $substate2000line = <FP>;
  $substate2000line =~ s/\s+$//;
  my @substate2000 = split(/,/, $substate2000line);

  if(scalar(@substate2000) == 0) {
    die "No insulation sub-states for 2000 are specified on the second line ",
      "of the insulation retrodiction file $file\n";
  }
  if(scalar(@substate2000) != scalar(@substate2010)) {
    die "There are a different number (", scalar(@substate2000), ") of ",
      "insulation sub-states for 2000 specified on the second line of the ",
      "insulation retrodiction file $file than there are insulation sub-",
      "states for 2010 on the first line (", scalar(@substate2010), ")\n";
  }
  
  my $probline = <FP>;
  $probline =~ s/\s+$//;
  my @prob = split(/,/, $probline);

  close(FP);

  if(scalar(@prob) == 0) {
    die "No probabilities of insulation sub-states are specified on the ",
      "third line of the insulation retrodiction file $file\n";
  }
  if(scalar(@prob) != scalar(@substate2010)) {
    die "There are a different number (", scalar(@prob), ") of probabilities ",
      "specified on the third line of the insulation retrodiction file $file ",
      "than there are insulation sub-states for 2000 or 2010 (",
      scalar(@substate2010), ") on either of the first two lines\n";
  }

  my %data;
  for(my $i = 0; $i <= $#prob; $i++) {
    if($prob[$i] < 0 || $prob[$i] > 1) {
      die "The probability for insulation sub-state in 2010 $substate2010[$i]",
	" (in 2000 $substate2000[$i]) on the third line of insulation ",
	"retrodiction file $file ($prob[$i]) is not in the range [0, 1]\n";
    }
    $data{$substate2010[$i]} = [$prob[$i], $substate2000[$i]];
  }

  return \%data;
}

# read_appliance_retrodiction ==> {subcategory}->prob
#
# Read the appliance retrodiction file

sub read_appliance_retrodiction {
  my ($file) = @_;

  open(FP, "<", $file)
    or die "Cannot open appliance retrodiction file $file for reading: $!\n";

  my $subcategoryline = <FP>;
  $subcategoryline =~ s/\s+$//;
  my @subcategory = split(/,/, $subcategoryline);

  if(scalar(@subcategory) == 0) {
    die "No appliance subcategories on the first line of the appliance ",
      "retrodiction file $file\n";
  }

  my $probline = <FP>;
  $probline =~ s/\s+$//;
  my @prob = split(/,/, $probline);

  close(FP);
  
  if(scalar(@prob) == 0) {
    die "No appliance subcategory probabilities on the second line of the ",
      "appliance retrodiction file $file\n";
  }
  if(scalar(@prob) != scalar(@subcategory)) {
    die "The number (", scalar(@prob), ") of probabilities on the second line",
      " of the appliance retrodiction file $file is not the same as the ",
      "number of appliance subcategories on the first (",
      scalar(@subcategory), ")\n";
  }

  my %data;
  for(my $i = 0; $i <= $#prob; $i++) {
    if($prob[$i] < 0 || $prob[$i] > 1) {
      die "The probability for appliance subcategory $subcategory[$i] on ",
	"the second line of the appliance retrodiction file $file ($prob[$i])",
	" is outside the range [0, 1]\n";
    }
    $data{$subcategory[$i]} = $prob[$i];
  }

  return \%data;
}

# read_sample ==> (samples...)
#
# Read some numbers from a file. Ostensibly, these are supposed to be samples
# from a distribution saved to a file, but in fact, they needn't be. If comma
# separated, only data from the first column will be read. If space-separated,
# all data will be read in. Space separated R output format can also be read.
# Only the required number of samples will be read, and it is an error if there
# aren't enough samples in the file.

sub read_sample {
  my ($file, $n) = @_;

  open(FP, "<", $file)
    or die "Cannot open sample file $file for reading: $!\n";

  my @data;
  
  while(my $line = <FP> && $n > 0) {
    $line =~ s/\s+$//;
    $line =~ s/^\s+(\[\d+\]\s+)?//;
    $line =~ s/,.*$//;
    my @cells = split(" ", $line);

    while(scalar(@cells) > 0 && $n > 0) {
      push(@data, shift(@cells));
      $n--;
    }
  }

  if($n > 0) {
    die "There aren't enough samples in sample file $file ($n more needed)\n";
  }

  close(FP);

  return @data;
}

# read_config
#
# Read configuration. The second argument to this function is expected to be
# a hash table of ARG, SETTINGS or SETUP to a reference to a data-structure to
# fill with the values

sub read_config {
  my ($file, $items) = @_;

  open(FP, "<", $file) or die "Cannot read config file $file: $!\n";

  my %found;
  while(my $line = <FP>) {
    $line =~ s/\s+$//;

    my @cells = split(/,/, $line);

    my $entry = shift(@cells);

    if(defined($$items{$entry})) {
      foreach my $value (@cells) {
	if($value =~ /^(.+)=(.+)$/) {
	  my ($key, $val) = ($1, $2);
	  $items->{$entry}->{$key} = $val;
	}
	else {
	  push(@{$$items{$entry}}, $value);
	}
      }
      $found{$entry} = 1;
    }
  }
  
  close(FP);

  foreach my $key (keys(%$items)) {
    if(!defined($found{$key})) {
      die "Could not find information $key in configuration file $file\n";
    }
  }
}

##############################################################################
# Other subroutines
##############################################################################

# select_query
#
# Select rows in a database that match a query

sub select_query {
  my ($query, $db) = @_;

  my @subd;

  for(my $i = 0; $i <= $#$db; $i++) {
    if(matches($query, $$db[$i], $i + 1)) {
      push(@subd, $$db[$i]);
    }
  }

  return \@subd;
}

# matches
#
# Test if a query matches a database entry the query is given in the following
# language:
#
# <query> := <conjquery> [OR <conjquery> ...]
# <conjquery> := <simplequery> [AND <simplequery> ...]
# <simplequery> := field <op> value
# <op> :- { SEQ NEQ SNE NNE GT GE LT LE MT NM }
#
# SEQ: string equal
# NEQ: numeric equal
# SNE: string not equal
# NNE: numeric not equal
# GT: numeric greater than
# GE: numeric greater than or equal
# LT: numeric less than
# LE: numeric less than or equal
# MT: string matches
# NM: string does not match

sub matches {
  my ($query, $entry, $entry_n) = @_;

  my @conjqueries = split(/ OR /, $query);

  foreach my $conjquery (@conjqueries) {

    my @simplequeries = split(/ AND /, $query);

    my $conj = 1;

    foreach my $simplequery (@simplequeries) {
      if($simplequery =~ /^(.+) SEQ (.+)$/) {
	$conj = 0 unless $$entry{$1} eq $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) NEQ (.+)$/) {
	$conj = 0 unless $$entry{$1} == $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) SNE (.+)$/) {
	$conj = 0 unless $$entry{$1} ne $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) NNE (.+)$/) {
	$conj = 0 unless $$entry{$1} != $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) GT (.+)$/) {
	$conj = 0 unless $$entry{$1} > $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) GE (.+)$/) {
	$conj = 0 unless $$entry{$1} >= $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) LT (.+)$/) {
	$conj = 0 unless $$entry{$1} < $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) LE (.+)$/) {
	$conj = 0 unless $$entry{$1} <= $2;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) MT (.+)$/) {
	$conj = 0 unless $$entry{$1} =~ /$2/;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^(.+) NM (.+)$/) {
	$conj = 0 unless $$entry{$1} !~ /$2/;
	die "Database has no field \"$1\"\n" if !defined($$entry{$1});
      }
      elsif($simplequery =~ /^EVERY (.+)$/) {
	$conj = 0 unless $entry_n % $1 == 0;
      }
      elsif($simplequery =~ /^PROB (.+)$/) {
	$conj = 0 unless rand 1 < $1;
      }
      elsif($simplequery =~ /^FROM (.+) TO (.+)$/) {
	$conj = 0 unless $entry_n >= $1 && $entry_n <= $2;
      }
      elsif($simplequery =~ /^LINE (.+) TO (.+)$/) {
	$conj = 0 unless $entry_n + 1 >= $1 && $entry_n + 1 <= $2;
      }
      else {
	die "Cannot find a recognisable operator in simple query $simplequery",
	  " (did you put spaces round the operator? and quotes round the ",
	  " whole query in the shell?)\n";
      }
      last if $conj == 0;
    }

    return 1 if $conj == 1;
  }

  # If we get here, none of the disjuncts are true
  return 0;
}

# parse_dist ==> (distribution, parameters...)
#
# A distribution string is given by a string, a bracket, a parameter list
# and a close bracket

sub parse_dist {
  my ($dist_str) = @_;

  if($dist_str =~ /^(\w+)\((.*)\)$/) {
    my ($dist, $parlist) = ($1, $2);

    $parlist =~ s/,\s+/,/g;	# Allow spaces after commas

    my @parms = split(/,/, $parlist);
    unshift(@parms, $dist);

    return @parms;
  }
  else {
    die "Invalid distribution string $dist_str\n";
  }
}

# sample_parse_R
#
# Sample distributions using R and parse a distribution string

sub sample_parse_R {
  my ($Rcmd, $n, $dist_str) = @_;

  my ($dist, @params) = &parse_dist($dist_str);

  return &sample_R($Rcmd, $dist, $n, @params);
}

# sample_R ==> (samples, ...)
#
# Sample distributions using R

sub sample_R {
  my ($Rcmd, $dist, $n, @params) = @_;
  
  my $rexpr;

  if($dist eq "all") {
    if(scalar(@params) != 1) {
      die "\"all\" distribution must be given one parameter. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    
    my @data;
    for(my $i = 1; $i <= $n; $i++) {
      push(@data, $params[0]);
    }
    return @data;
  }
  elsif($dist eq "uniform") {
    if(scalar(@params) != 2) {
      die "Uniform distribution must be given two parameters. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "runif($n, min = $params[0], max = $params[1])";
  }
  elsif($dist eq "uniformint") {
    if(scalar(@params) != 2) {
      die "Uniform integer distribution must be given two parameters. ",
	"Parameters passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "floor(runif($n, min = $params[0], max = ", $params[1] + 1, "))";
  }      
  elsif($dist eq "normal") {
    if(scalar(@params) != 2) {
      die "Normal distribution must be given two parameters. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rnorm($n, mean = $params[0], sd = $params[1])";
  }
  elsif($dist eq "lognormal") {
    if(scalar(@params) != 2) {
      die "Log normal distribution must be given two parameters. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rlnorm($n, meanlog = $params[0], sdlog = $params[1])";
  }
  elsif($dist eq "exponential") {
    if(scalar(@params) != 1) {
      die "Exponential distribution must be given one parameter. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rexp($n, rate = ".(1 / $params[0]).")";
  }
  elsif($dist eq "binomial") {
    if(scalar(@params) != 2) {
      die "Binomial distribution must be given two parameters. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rbinom($n, size = $params[0], prob = $params[1])";
  }
  elsif($dist eq "chisquared") {
    if(scalar(@params) != 2) {
      die "Chi squared distribution must be given two parameters. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rchisq($n, df = $params[0], ncp = $params[1])";
  }
  elsif($dist eq "poisson") {
    if(scalar(@params) != 1) {
      die "Poisson distribution must be given one parameter. Parameters ",
	"passed are [", join(", ", @params), "]\n";
    }
    $rexpr = "rpois($n, lambda = ".(1 / $params[0]).")";
  }
  else {
    die "Unrecognised distribution $dist\n";
  }

  my $Rexec = "$Rcmd -e \'$rexpr\'";
  open(R, "-|", $Rexec)
    or die "Cannot connect to R with command $Rexec: $!\n";

  my @data;
  while(my $line = <R>) {
    $line =~ s/\s+$//;
    $line =~ s/^\s+//;

    my @entries = split(" ", $line);

    if($entries[0] =~ /^\[\d+\]$/) {
      shift(@entries);
    }

    push(@data, @entries);
  }

  close(R);

  return @data;
}

# cp
#
# Copy a file from one place to another

sub cp {
  my ($src, $dest, $link) = @_;

  if(!-e "$src") {
    die "Cannot copy non-existent file $src\n";
  }
  if(-e "$dest") {
    die "Destination file $dest exists and won't be overwritten\n";
  }

  if(defined($link) && $link == 1) {
    # Need to find out relative path from dest to src
    my $abs_src = abs_path($src);
    my $abs_dest = abs_path($dest);
    my @src_arr = split(/\//, $abs_src);
    my @dest_arr = split(/\//, $abs_dest);

    while($src_arr[0] eq $dest_arr[0]) {
      shift(@src_arr);
      shift(@dest_arr);
    }

    my $rel_src = "../" x (scalar(@dest_arr) - 1);
    $rel_src .= join("/", @src_arr);

    if(!symlink($rel_src, $dest)) {
      die "Cannot make a symbolic link from $rel_src to $dest: $!\n";
    }
    if(scalar(stat($dest)) == 0) {
      die "Failed to correctly build a symbolic link from $rel_src to $dest\n";
    }
    return;
  }
  
  my $bytes = -s "$src";

  open(SRC, "<", $src) or die "Cannot open source file $src for copying: $!\n";

  my $wholefile;

  my $read = sysread(SRC, $wholefile, $bytes);

  if(!defined($read)) {
    die "Error reading $bytes bytes from file $src: $!\n";
  }
  if($read != $bytes) {
    die "Failed to read $bytes bytes from file $src (only read $read bytes)\n";
  }
  
  close(SRC);
  
  open(DEST, ">", $dest)
    or die "Cannot create destination file $dest for copying $src: $!\n";

  my $written = syswrite(DEST, $wholefile);

  if(!defined($written)) {
    die "Error writing $bytes bytes to file $dest: $!\n";
  }
  if($written != $bytes) {
    die "Failed to write $bytes bytes to file $dest (only wrote ",
      "$written bytes)\n";
  }
  
  close(DEST);
}
  

# parse_nlogo_gui_params
#
# Read the parameters and their settings from the netlogo file, returning
# them as an option

sub parse_nlogo_gui_params {
  my ($file) = @_;

  open(FP, "<", $file)
    or die "Cannot open NetLogo file $file for reading: $!\n";

  my $in_graphics_window = 0;
  my $last_line_sep = 0;
  my $last_line_blank = 0;

  my @params;
  
  while(my $line = <FP>) {
    $line =~ s/\s*$//;

    if($line eq '@#$#@#$#@') {
      $last_line_sep = 1;
      $in_graphics_window = 0;
      $last_line_blank = 0;
      next;
    }
    if($last_line_sep && $line eq 'GRAPHICS-WINDOW') {
      $in_graphics_window = 1;
      $last_line_sep = 0;
      $last_line_blank = 0;
      next;
    }
    $last_line_sep = 0;
    if($line eq '') {
      $last_line_blank = 1;
      next;
    }

    if($last_line_blank && $line eq 'SLIDER') {
      push(@params, &read_slider(*FP));
    }
    elsif($last_line_blank && $line eq 'SWITCH') {
      push(@params, &read_switch(*FP));
    }
    elsif($last_line_blank && $line eq 'INPUTBOX') {
      push(@params, &read_inputbox(*FP));
    }
    elsif($last_line_blank && $line eq 'CHOOSER') {
      push(@params, &read_chooser(*FP));
    }
  }

  close(FP);

  my %param;

  foreach my $p (@params) {
    $param{$$p[1]} = $p;
  }
  
  return \%param;
}

# read_slider
#
# See https://github.com/NetLogo/NetLogo/wiki/Widget-Format#sliders
#
# Read five lines then get the name of the slider then read two
# lines then get the value (the default value)

sub read_slider {
  my ($fp) = @_;

  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  my $name = <$fp>;
  $name =~ s/\s+$//;
  <$fp>;
  <$fp>;
  my $value = <$fp>;
  $value =~ s/\s+$//;

  return ['SLIDER', $name, $value];
}

# read_switch
#
# See https://github.com/NetLogo/NetLogo/wiki/Widget-Format#switches
#
# Read five lines then get the name of the switch then
# get the value (0 = on, 1 = off)

sub read_switch {
  my ($fp) = @_;

  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  my $name = <$fp>;
  $name =~ s/\s+$//;
  my $value = <$fp>;
  $value =~ s/\s+$//;
  $value = ($value == 0) ? 'true' : 'false';

  return ['SWITCH', $name, $value];
}

# read_inputbox
#
# Read four lines then get the name of the inputbox then the value

sub read_inputbox {
  my ($fp) = @_;

  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  my $name = <$fp>;
  $name =~ s/\s+$//;
  my $value = <$fp>;
  $value =~ s/\s+$//;
  <$fp>;
  <$fp>;
  my $type = <$fp>;
  $type =~ s/\s+$//;

  return ['INPUTBOX', $name, $value, $type];
}

# read_chooser
#
# See https://github.com/NetLogo/NetLogo/wiki/Widget-Format#choosers
#
# Read five lines then get the name of the chooser then get the values,
# then get the index in the values (starting at 0)

sub read_chooser {
  my ($fp) = @_;

  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  <$fp>;
  my $name = <$fp>;
  $name =~ s/\s+$//;
  my $options = <$fp>;
  $options =~ s/\s+$//;
  my $selection = <$fp>;
  $selection =~ s/\s+$//;

  my $value = (split(" ", $options))[$selection];

  return ['CHOOSER', $name, $value, $options];
}
  
