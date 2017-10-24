#!/usr/bin/perl
#
# MGAcalib.pl
#
# Script to run a multi-criteria GA over a model to find calibration parameters
#
# The genome consists of parameters that are adjusted.
#
# The inputs to this program are:
#
# 1. A file describing the parameters
#
# 2. A file describing the GA parameters
#
# 3. A program to call that takes a parameter genome and runs the model
#
# 4. A program to call that processes the model output and returns a vector
#    of fit parameters

use strict;
use Errno qw(EAGAIN);
use Math::Trig;
use Cwd;

if(scalar(@ARGV) < 4 && $ARGV[0] ne 'continue') {
  die "Usage 1: $0 [-maxproc <max concurrent processes>] ",
  "<parameter file> <GA file> <model script> <fitness script>\n",
  "\n",
  "\tThe parameter file describes all the parameters -- there will be one\n",
  "\telement on the genome for each parameter. Prior distributions for the\n",
  "\tparameters are specified here, as is the fitness vector.\n"
  "\n",
  "\tThe GA information includes the population size, rule and rule\n",
  "\tparameters, as well as configuration options for the model and fitness\n",
  "\tscripts.\n",
  "\n",
  "\tThe model script should be able to process a file saved by this ",
  "\tprogram stating the parameter setting the model is to explore, and call ",
  "\tthe model to get the output.\n",
  "\n",
  "\tThe fitness script should process the model output and return a file\n",
  "\tparsed by this program to compute the fitness vector\n",
  "\n",
  "\n",
  "Usage 2: $0 continue [-maxproc <max concurrent processes>] <continuation ",
  "file>\n",
  "\n",
  "\tThe continuation file is saved by the program when it has finished the\n",
  "\tspecified number of generations\n";
}

my @contpop;
my @contfit;
my @contid;
my $continuing = 0;
my @contargv;
my $contfile;
my $prevwd;
my $prevdata = 0;
if($ARGV[0] eq 'continue') {
  $continuing = 1;
  shift(@ARGV);
  $contfile = shift(@ARGV);
  my @loadargv;
  my ($cwd, $wd) = &loadga($contfile, \@contpop, \@contfit, \@contid,
			   \@loadargv);
  $prevwd = $wd;
  chdir $cwd or die "Cannot chdir $cwd: $!\n";
  push(@contargv, @ARGV);
  @ARGV = @loadargv;

  my $prevdata = 1;
  for(my $i = 0; $i <= $#contid; $i++) {
    if(!-d "$prevwd/$contid[$i]") {
      $prevdata = 0;
      last;
    }
  }
}  

# TODO Add an option to use condor

my $maxproc = 1;
my $wd = $continuing ? $prevwd : "/var/tmp/MGAcalib/$$";
my $delete = 0;			# 1 => Delete runs
my $keephof = 1;		# 1 => Keep only hall of fame
my $nohalf = 1;

my $log = "LOG";

my @saveargv;
push(@saveargv, @ARGV);

while($ARGV[0] =~ /^-/ || scalar(@contargv) > 0) {
  my $option;
  my $shiftarr;

  if($ARGV[0] =~ /^-/) {
    $option = shift(@ARGV);
    $shiftarr = \@ARGV;
  }
  elsif($contargv[0] =~ /^-/) {
    $option = shift(@contargv);
    $shiftarr = \@contargv;
  }
  else {
    die "Invalid argument to continuation run: $contargv[0]\n";
  }

  if($option eq '-maxproc') {
    $maxproc = shift(@$shiftarr);
  }
  elsif($option eq '-keepall') {
    $keephof = 0;
    $delete = 0;
  }
  elsif($option eq '-deleteall') {
    $delete = 1;
    $keephof = 1;
  }
  elsif($option eq '-keephof') {
    $delete = 0;
    $keephof = 1;
  }
  elsif($option eq '-wd') {
    $wd = shift(@$shiftarr);
  }
  elsif($option eq '-log') {
    $log = shift(@$shiftarr);
  }
  else {
    die "Unrecognised command-line option: $option\n";
  }
}

if(!-e $wd) {
  mkdir $wd or die "Cannot create working directory $wd: $!\n";
}
 
$log = "$wd/$log" if $log !~ /\//;

if(!-e "$log") {
  open(LOG, ">>$log") or die "Cannot create log file $log: $!\n";
  close(LOG);
}

my $paramFile = shift(@ARGV);
my $gaFile = shift(@ARGV);
my $modelScript = shift(@ARGV);
my $fitnessScript = shift(@ARGV);

&log("Started. Parameter file $paramFile, GA file $gaFile, model script ".
     "$modelScript, fitness script $fitnessScript");

if($continuing) {
  &log("N.B. Continuing from file $contfile");
}

my ($npop, $ngen, $rule, $param, $search, $types, $priors, $constraints,
    $config_model, $config_fitness)
  = &readga($paramFile, $gaFile);

# Adjust the fitness and model run script commands to use the configuration
# options

while(my($key, $value) = each(%$config_model)) {
  $modelScript .= " -config \"$key\" \"$value\"";
}

while(my($key, $value) = each(%$config_fitness)) {
  $fitnessScript .= " -config \"$key\" \"$value\"";
}

# Initialise population

my @population;
if($continuing) {		# Continuing: use loaded population
  @population = @contpop;
  if(scalar(@population) != $npop) {
    die "Cannot continue: failed to load exactly $npop instances from file ",
    "$contfile. Number loaded: ", scalar(@population), "\n";
  }
}
else {				# Not continuing: build population
  @population = &buildpop($npop, $types, $priors, $constraints);
}

my @identifiers;
my @fitness;
if($prevdata) {			# Continuing and data from previous runs found
  @identifiers = @contid;
  @fitness = @contfit;
  if($wd ne $prevwd) {
    for(my $i = 0; $i <= $#identifiers; $i++) {
      &cp("$prevwd/$identifiers[$i]", "$wd/$identifiers[$i]");
    }
  }
}
else {				# (Re)calculate the fitness
  @fitness = &calcfitness($modelScript, $fitnessScript, $search,
			  \@biophysFiles, \@population, \@identifiers);
  if($continuing) {
    for(my $i = 0; $i <= $#fitness; $i++) {
      &log("Run $identifiers[$i] (previously $contid[$i]) has fitness",
	   "$fitness[$i] (previously $contfit[$i])");
    }
  }
}

my @halloffame;			# [[pop data], fitness, gen, id]

my ($ntrans, $front)
  = &maintainhalloffame(\@halloffame, \@population, \@fitness,
			0, $param, \@identifiers);
&log("Generation 0: $ntrans moved to hall of fame;",
     "best fitnesses", &frontstr($front));

# Main GA loop

for(my $gen = 1; $gen <= $ngen; $gen++) {

  my $fitnessarr = \@fitness;
  
  if(defined($$param{'sigmashare'})) {
    $fitnessarr = &sharefitness($fitnessarr, $$param{'sigmashare'},
				(defined($$param{'distnorm'})
				 ? $$param{'distnorm'} : 2));
  }

  my @newpopulation;

  if($rule =~ /indiv/) {
    @newpopulation = &breedind($rule, $param, $types, $priors, $constraints,
			       \@population, $fitnessarr);
  }
  else {
    @newpopulation = &breed($rule, $param, $types, $priors, $constraints,
			    \@population, $fitnessarr);
  }
  
  my @newidentifiers;
  my @newfitness = &calcfitness($modelScript, $fitnessScript, $search,
				\@newpopulation, \@newidentifiers);


  my ($ntrans, $front)
    = &maintainhalloffame(\@halloffame, \@newpopulation, \@newfitness,
			  $gen, $param, \@newidentifiers);

  &log("Generation $gen: $ntrans moved to hall of fame;",
     "best fitnesses", &frontstr($front));

  &selectpop($rule, $param, $gen,
	     \@population, \@fitness, \@newpopulation, \@newfitness,
	     \@identifiers, \@newidentifiers);

  # Adjust parameters if required

  foreach my $key (keys(%$param)) {
    next if $key =~ /^_[DTB]/;

    if(defined($$param{"_D$key"})) {
      my $delta = $$param{"_D$key"};

      next if(defined($$param{"_T0$key"}) && $gen < $$param{"_T0$key"});
      next if(defined($$param{"_T1$key"}) && $gen > $$param{"_T1$key"});

      $$param{$key} += $delta;
      if(defined($$param{"_B$key"})) {
	if(($delta < 0 && $$param{$key} < $$param{"_B$key"})
	   || ($delta > 0 && $$param{$key} > $$param{"_B$key"})) {
	  $$param{$key} = $$param{"_B$key"};
	}
      }
    }
  }
}

&savega($wd, \@population, \@fitness, \@identifiers,
	\@saveargv, $search);

for(my $i = 0; $i <= $#halloffame; $i++) {
  &log("Hall of fame position ", $i + 1, "fitness",
       &fitnessstr($halloffame[$i][1]),
       "found in generation $halloffame[$i][2] (run $halloffame[$i][3]):",
       &popstr($halloffame[$i][0], $search, \@biophysFiles));
}

&log("Stopped");

exit 0;

###############################################################################
# =====================
# S U B R O U T I N E S
# =====================
#
###############################################################################

##############################################################################
#
# G A   O P E R A T I O N S
#
##############################################################################

# buildpop(npop, priors, constraints) -> population
#
# Build a random new population with npop members, using the priors to sample
# and the constraints to reject samples.

sub buildpop {
  my ($npop, $types, $priors, $constraints) = @_;

  my @population;

  for(my $pop = 0; $pop < $npop; $pop++) {
    $population[$pop] = &samplepop($types, $priors, $constraints);
  }

  return @population;
}

# calcfitness(modelScript, fitnessScript, search, population, identifiers)
#                                                                    -> fitness
#
# Compute the fitness of each member of the population. This is done in
# separate steps to enable parallel execution. First all the runs are started,
# then we wait for the runs to complete, then we compute the fitness.

sub calcfitness {
  my ($modelScript, $fitnessScript, $search, $population, $identifiers) = @_;

  my @fitness;

  for(my $pop = 0; $pop <= $#$population; $pop++) {
    $$identifiers[$pop] = &startrun($modelScript, $search,
				    $$population[$pop]);
  }

  &waitforruns($identifiers);

  my %dir2ix;
  for(my $pop = 0; $pop <= $#$population; $pop++) {
    my $dir = &runfitness($$identifiers[$pop], $fitnessScript, \%dir2ix,
			  $identifiers, \@fitness);
    $dir2ix{$dir} = $pop;
  }

  &waitfit(1, \%dir2ix, $identifiers, \@fitness);
  
  return @fitness;
}

##############################################################################
#
# Selection
#
##############################################################################

# selectpop(rule, param, population, fitness, newpopulation, newfitness)
#
# Use a proposed new population to replace the current one, applying various
# different rules to determine how this is done.

sub selectpop {
  my($rule, $param, $gen, $population, $fitness, $newpopulation, $newfitness,
     $identifiers, $newidentifiers) = @_;

  if($rule eq 'DEStrict' || $rule =~ /pos/) {
    for(my $i = 0; $i <= $#$population; $i++) {
      my $cmp = &cmpvector($$newfitness[$i], $$fitness[$i]);
      if($cmp > 0) {
	$$population[$i] = $$newpopulation[$i];
	$$identifiers[$i] = $$newidentifiers[$i];
	$$fitness[$i] = $$newfitness[$i];
      }
    }
  }
  elsif($rule =~ /^DEMCStrict/ || $rule =~ /probos/) {
    for(my $i = 0; $i <= $#$population; $i++) {
      my $r = &meanratiovector($$newfitness[$i], $$fitness[$i]);
      if(rand() < $r) {
	$$population[$i] = $$newpopulation[$i];
	$$identifiers[$i] = $$newidentifiers[$i];
	$$fitness[$i] = $$newfitness[$i];
      }
    }
  }
  elsif($rule =~ /^DEMCRlen/ || $rule =~ /lenprob/) {
    for(my $i = 0; $i <= $#$population; $i++) {
      my $r = &lengthratiovector($$newfitness[$i], $$fitness[$i]);
      if(rand() < $r) {
	$$population[$i] = $$newpopulation[$i];
	$$identifiers[$i] = $$newidentifiers[$i];
	$$fitness[$i] = $$newfitness[$i];
      }
    }
  }
  elsif($rule =~ /^DEMCZ/) {
    if($gen > 0 && $gen % $$param{'K'} == 0) {
      for(my $i = 0; $i <= $$param{'chains'}; $i++) {
	push(@$population, $$newpopulation[$i]);
	push(@$identifiers, $$newidentifiers[$i]);
	push(@$fitness, $$newfitness[$i]);
      }
    }
    else {
      for(my $i = 0; $i <= $$param{'chains'}; $i++) {
	my $r;
	if($rule eq 'DEMCZStrict') {
	  $r = &meanratiovector($$newfitness[$i], $$fitness[$i]);
	}
	else {
	  $r = &lengthratiovector($$newfitness[$i], $$fitness[$i]);
	}
	if(rand() < $r) {
	  $$population[$i] = $$newpopulation[$i];
	  $$identifiers[$i] = $$newidentifiers[$i];
	  $$fitness[$i] = $$newfitness[$i];
	}
      }
    }
  }
  elsif($rule =~ /top/ || $rule =~ /indiv/) {
    &selecttop($rule, $param, $population, $fitness, $newpopulation,
	       $newfitness, $identifiers, $newidentifiers);
  }
  elsif($rule =~ /new/) {
    for(my $i = 0; $i <= $#$population; $i++) {
      $$population[$i] = $$newpopulation[$i];
      $$identifiers[$i] = $$newidentifiers[$i];
      $$fitness[$i] = $$newfitness[$i];
    }
  }
  else {
    die "Unable to determine selection process from rule $rule\n";
  }
}

# selecttop(population, fitness, newpopulation, newfitness
#
# The new population consists of the top N members of population and
# newpopulation, where N is the population size.

sub selecttop {
  my ($rule, $param, $population, $fitness, $newpopulation, $newfitness,
      $identifiers, $newidentifiers) = @_;

  my @wholepopulation = (@$population, @$newpopulation);
  my @wholefitness = (@$fitness, @$newfitness);
  my @wholeidentifiers = (@$identifiers, @$newidentifiers);

  my $fitnessarr = \@wholefitness;

  if(defined($$param{'sigmashare'})) {
    $fitnessarr = &sharefitness($fitnessarr, $$param{'sigmashare'},
				(defined($$param{'distnorm'})
				 ? $$param{'distnorm'} : 2));
  }

  my @sorted;
  if($rule =~ /dominance/) {
    @sorted = &sortbydominance($finessarr);
  }
  else {
    @sorted = &sortbyfitness($fitnessarr);
  }
  
  for(my $i = 0; $i <= $#$population; $i++) {
    $$population[$i] = $wholepopulation[$sorted[$i]];
    $$identifiers[$i] = $wholeidentifiers[$sorted[$i]];
    $$fitness[$i] = $wholefitness[$sorted[$i]];
				# N.B. Keep original fitness, not
				# shared fitness, in the fitness array
  }
}

##############################################################################
#
# Breeding
#
##############################################################################

# breed(rule, param, priors, constraints, population, fitness) -> new pop
#
# Generate a new population of samples to explore

sub breed {
  my ($rule, $param, $types, $priors, $constraints, $population,
      $fitness) = @_;

  my @newpopulation;

  for(my $i = 0; $i <= $#$population; $i++) {
    my $sample;

    do {
      if($rule =~ /^DEMCZ/) {
	$sample = &breedDEMCZ($rule, $param, $types, $priors,
			      $population, $fitness, $i);
      }
      elsif($rule =~ /^DEMC/) {
	$sample = &breedDEMC($rule, $param, $types, $priors,
			     $population, $fitness, $i);
      }
      elsif($rule =~ /^DE/) {
	$sample = &breedDE($rule, $param, $types, $priors, $population,
			   $fitness, $i);
      }
      elsif($rule =~ /^[OM]?GA/) {
	my @sorted;

	if($rule =~ /dominance/) {
	  @sorted = &sortbydominance($fitness);
	}
	else {
	  @sorted = &sortbyfitness($fitness);
	}

	if($rule =~ /^GA/) {
	  $sample = &breedGA($rule, $param, $types, $priors, $population,
			     $fitness, $i, \@sorted);
	}
	elsif($rule =~ /^MGA/) {
	  $sample = &breedMGA($rule, $param, $types, $priors, $population,
			      $fitness, $i, \@sorted);
	}
	elsif($rule =~ /^OGA/) {
	  $sample = &breedOGA($rule, $param, $types, $priors, $population,
			      $fitness, $i, \@sorted);
	}      
	
      }
      else {
	die "Unrecognised breeder rule: $rule\n";
      }
    } while(!&constrainednall($sample, $constraints));

    for(my $j = 0; $j <= $#$sample; $j++, $i++) {
      $newpopulation[$i] = $$sample[$j];
    }
  }

  return @newpopulation;
}

# breedind
#
# Breed method creating a specific number of children from the current
# population

sub breedind {
  my ($rule, $param, $types, $priors, $constraints, $population, $fitness) = @_;

  my @newpopulation;

  if(!defined($$param{'newkids'})) {
    die "You must define the \"newkids\" parameter when using rule $rule\n";
  }

  my $n = $$param{'newkids'};

  my @sorted = ($rule =~ /dominance/)
    ? &sortbydominance($fitness) : &sortbyfitness($fitness);

  for(my $i = 0; $i < $newkids; $i++) {
    my $sample;
    
    if($rule =~ /^GA/) {
      $sample = &breedGA($rule, $param, $types, $priors, $population,
			 $fitness, $i, \@sorted);
    }
    elsif($rule =~ /^MGA/) {
      $sample = &breedMGA($rule, $param, $types, $priors, $population,
			 $fitness, $i, \@sorted);
    }
    elsif($rule =~ /^OGA/) {
      $sample = &breedOGA($rule, $param, $types, $priors, $population,
			 $fitness, $i, \@sorted);
    }

    $newpopulation[$i] = $sample;
  }

  return @newpopulation;
}

# breedDEMCZ(rule, param, priors, population, fitness, i) -> baby
#
# Use the breeder rule (2) in ter Braak (2008) to determine the new sample
# to explore

sub breedDEMCZ {
  my ($rule, $param, $types, $priors, $population, $fitness, $i) = @_;

  my $popsize = scalar(@$population) - $$param{'chains'};
  my $R1 = int(rand($popsize - 1));
  $R1++ if $R1 >= $i;
  my $R2 = int(rand($popsize - 2));
  $R2++ if $R2 >= ($i < $R1 ? $i : $R1);
  $R2++ if $R2 >= ($i > $R1 ? $i : $R1);

  $R1 += $$param{'chains'};
  $R2 += $$param{'chains'};

  my $gene = &subvector($$population[$R1], $$population[$R2]);
  $gene = &scalevector($gene, $$param{'gamma'});
  $gene = &addvector($$population[$i], $gene);
  if($rule =~ /Normal/) {
    $gene = &perturbnormalvector($gene, $$param{'b'});
  }
  else {
    $gene = &perturbvector($gene, $$param{'b'});
  }

  if(defined($$param{'CR'})) {
    $gene = &crossoverDEMC($gene, $$population[$i], $$param{'CR'});
  }

  $gene = &normalisevector($gene, $types, $priors);

  return [$gene];
}

# breedDEMC(rule, param, priors, population, fitness, i) -> baby
#
# Use the breeder rule (2) in ter Braak (2004) to determine the new sample
# to explore

sub breedDEMC {
  my ($rule, $param, $types, $priors, $population, $fitness, $i) = @_;

  my $popsize = scalar(@$population);
  my $R1 = int(rand($popsize - 1));
  $R1++ if $R1 >= $i;
  my $R2 = int(rand($popsize - 2));
  $R2++ if $R2 >= ($i < $R1 ? $i : $R1);
  $R2++ if $R2 >= ($i > $R1 ? $i : $R1);

  my $gene = &subvector($$population[$R1], $$population[$R2]);
  $gene = &scalevector($gene, $$param{'gamma'});
  $gene = &addvector($$population[$i], $gene);
  if($rule =~ /Normal/) {
    $gene = &perturbnormalvector($gene, $$param{'b'});
  }
  else {
    $gene = &perturbvector($gene, $$param{'b'});
  }

  if(defined($$param{'CR'})) {
    $gene = &crossoverDEMC($gene, $$population[$i], $$param{'CR'});
  }

  $gene = &normalisevector($gene, $types, $priors);

  return [$gene];
}

# breedDE(rule, param, priors, population, fitness, i) -> baby
#
# Use the more traditional differential evolution rule (1) in ter Braak (2004)
# to build the proposal

sub breedDE {
  my ($rule, $param, $priors, $population, $fitness, $i) = @_;

  my $popsize = scalar(@$population);
  my $R0 = int(rand($popsize));
  my $R1 = int(rand($popsize));
  my $R2 = int(rand($popsize));

  my $gene = &subvector($$population[$R1], $$population[$R2]);
  $gene = &scalevector($gene, $$param{'gamma'});
  $gene = &addvector($$population[$R0], $gene);

  $gene = &normalisevector($gene, $types, $priors);

  return [$gene];
}

# breedGA(rule, param, priors, population, fitness, i) -> baby
#
# Use a more traditional GA breeding rule, which generates a new sample by
# applying genetic operators to selected parents.

sub breedGA {
  my ($rule, $param, $types, $priors, $population, $fitness, $i, $sorted) = @_;

  my $S1 = &sampleranklottery($sorted);
  my $S2 = &sampleranklottery($sorted);

  my $gene = ((rand() < $$param{'pcrossover'})
	      ? &crossover($$population[$S1], $$population[$S2])
	      : (rand() < 0.5 ? $$population[$S1] : $$population[$S2]));
  $gene = &mutate($gene, $$param{'pmutate'}, $priors);

  if(defined($$param{'b'})) {
    my $pperturb = defined($$param{'pperturb'}) ? $$param{'pperturb'} : 1;
    $gene = &perturb($gene, $types, $pperturb, $$param{'b'});
  }

  return [$gene];
}

# breedMGA
#
# Breed using a traditional GA rule, but with the multicrossover operator

sub breedMGA {
  my ($rule, $param, $types, $priors, $population, $fitness, $i, $sorted) = @_;

  my $S1 = &sampleranklottery($sorted);
  my $S2 = &sampleranklottery($sorted);

  my $gene = ((rand() < $$param{'pmulticrossover'})
	      ? &multicrossover($$population[$S1], $$population[$S2],
			        $$param{'multicrossoverp'})
	      : ((rand() < $$param{'pcrossover'})
		 ? &crossover($$population[$S1], $$population[$S2])
		 : (rand() < 0.5 ? $$population[$S1] : $$population[$S2])));
  $gene = &mutate($gene, $$param{'pmutate'}, $priors);

  if(defined($$param{'b'})) {
    my $pperturb = defined($$param{'pperturb'}) ? $$param{'pperturb'} : 1;
    $gene = &perturb($gene, $types, $pperturb, $$param{'b'});
  }

  return [$gene];
}

# breedOGA
#
# Breed using one operator at a time, selecting only those parents needed
# for the operator

sub breedOGA {
  my ($rule, $param, $types, $priors, $population, $fitness, $i, $sorted) = @_;

  my @ops = ("wcrossover", "wmulticrossover", "wcrossoverDEMC", "wmutate",
	     "wperturb");
  my @oparr;

  for(my $i = 0; $i <= $#ops; $i++) {
    $oparr[$i] = defined($$param{$ops[$i]}) ? $$param{$ops[$i]} : 0;
    if($oparr[$i] < 0) {
      die "Error: $ops[$i] must not be negative ($oparr[$i])\n";
    }
  }

  my $sum = $oparr[0];
  for(my $i = 1; $i <= $#oparr; $i++) {
    $sum += $oparr[$i];
    $oparr[$i] = $sum;
  }
  if($sum == 0) {
    die "Under OGA rules, the operators are specified with weights using ",
      "parameters ", join(", ", @ops), "; these must be non-negative, are 0 ",
      "by default, but must have a positive sum. (You probably haven't ",
      "defined them.)\n";
  }
  my $choice = rand($sum);
  for(my $i = 0; $i <= $#oparr; $i++) {
    if($choice < $oparr[$i]) {
      if($ops[$i] eq 'wcrossover') {
	my $S1 = &sampleranklottery($sorted);
	my $S2 = &sampleranklottery($sorted);
	return &crossover2($$population[$S1], $$population[$S2]);
      }
      elsif($ops[$i] eq 'wmulticrossover') {
	my $S1 = &sampleranklottery($sorted);
	my $S2 = &sampleranklottery($sorted);
	if(!defined($$param{'multicrossoverp'})) {
	  die "The \"multicrossoverp\" parameter must be defined if you are ",
	    "using multicrossover\n";
	}
	return &multicrossover2($$population[$S1], $$population[$S2],
				$$param{'multicrossoverp'});
      }
      elsif($ops[$i] eq 'wcrossoverDEMC') {
	my $S1 = &sampleranklottery($sorted);
	my $S2 = &sampleranklottery($sorted);
	if(!defined($$param{'CR'})) {
	  die "The \"CR\" parameter must be defined if you are ",
	    "using multicrossover\n";
	}
	return &crossoverDEMC2($$population[$S1], $$population[$S2],
			       $$param{'CR'});
      }
      elsif($ops[$i] eq 'wmutate') {
	my $S1 = &sampleranklottery($sorted);
	return [&mutate($$population[$S1], 1, $priors)];
      }
      elsif($ops[$i] eq 'wperturb') {
	my $S1 = &sampleranklottery($sorted);
	if(!defined($$param{'b'})) {
	  die "The b parameter must be defined if you are using perturb\n";
	}
	return [&perturb($$population[$S1], $types, 1, $$param{'b'})];
      }
      else {
	die "Panic!";
      }
    }
  }
}

# sampleranklottery(sorted) -> sample index
#
# Select from an array of sorted indexes using a lottery where i tickets are
# given to the ith member (thus member N, the best member, gets N tickets, 
# whilst the worst member gets 1 ticket).

sub sampleranklottery {
  my ($sorted) = @_;

  my $popsize = scalar(@$sorted);
  my $ntickets = $popsize * ($popsize + 1) / 2.0;

  my $ticket = rand() * $ntickets;
  my $tticket = 0;
  for(my $j = 0; $j <= $#$sorted; $j++) {
    $tticket += $j + 1;
    if($tticket >= $ticket) {
      return $$sorted[$j];
    }
  }
  return $$sorted[$#$sorted];
}

##############################################################################
#
# Population sorting and fitness sharing
#
##############################################################################

# sortbyfitness(fitness) -> array of indexes
#
# Build an array of indexes on fitness that would be used to create an array
# of fitness sorted in ascending order. Since we now have a partial ordering,
# this is done by successively finding the pareto front and 'unshifting' that
# on to the front of the sorted array of indexes. The pareto front array must
# be shuffled so there is no bias in which unordered solutions are prefered.

sub sortbyfitness {
  my ($fitness) = @_;

  my @sorted;

  my @front;
  do {
    @front = &shuffle(&paretofront($fitness, @sorted));
    unshift(@sorted, @front);
  } while(scalar(@front) > 0);

  return @sorted;
}

# sortbydominance
#
# Sort the fitnesses by a count of the number of other fitnesses they
# dominate (i.e. by having better values for all fitnesses)

sub sortbydominance {
  my ($fitness) = @_;

  my @dom;
  my @sorted;

  for(my $i = 0; $i <= $#$fitness; $i++) {
    $sorted[$i] = $i;
    $dom[$i] = 0;
  }

  for(my $i = 0; $i < $#$fitness; $i++) {
    for(my $j = $i + 1; $j <= $#$fitness; $j++) {
      my $cmp = &pocmpvector($$fitness[$i], $$fitness[$j]);
      if($cmp ne 'incomparable') {
	if($cmp < 0) {
	  $dom[$j]++;
	}
	elsif($cmp > 0) {
	  $dom[$i]++;
	}
      }
    }
  }

  @sorted = &shuffle(@sorted);
  @sorted = sort { $dom[$a] <=> $dom[$b] } @sorted;
  return @sorted;
}

# paretofront(fitness, notarr) -> pareto front
#
# Find the set of incomparable best fitnesses in the fitness array, with the
# exception of those in notarr. These may be assumed to be fitnesses that have
# already been found. The algorithm is possibly not the most efficient.

sub paretofront {
  my ($fitness, @notarr) = @_;

  my @front;
  my %not;

  foreach my $notthis (@notarr) {
    $not{$notthis} = $notthis;
  }

  my $i;
  for($i = 0; $i <= $#$fitness; $i++) {
    if(!defined($not{$i})) {
      push(@front, $i);
      last;
    }
  }
  for(; $i <= $#$fitness; $i++) {
    next if defined($not{$i});
    my $allincomparable = 1;
    my $added = 0;
    for(my $j = 0; $j <= $#front; $j++) {
      my $cmp = &pocmpvector($$fitness[$i], $$fitness[$front[$j]]);
      if($cmp ne 'incomparable') {
	$allincomparable = 0;
	if($cmp > 0) {
	  if(!$added) {
	    $front[$j] = $i;
	    $added = 1;
	  }
	  else {
	    splice(@front, $j, 1);
	  }
	}
      }
    }
    push(@front, $i) if $allincomparable;
  }

  return @front;
}

# sharefitness(fitness, sigmashare, norm) -> shared fitness
#
# Implement shared fitness using a triangular fitness sharing function

sub sharefitness {
  my ($fitness, $sigmashare, $norm) = @_;

  my $dist = &distancematrix($fitness, $norm);

  my @sharedfitness;
  for(my $i = 0; $i <= $#fitness; $i++) {
    my $sum = 0;
    for(my $j = 0; $j <= $#fitness; $j++) {
      # Important that we include $i to avoid 0 $sum
      if($$dist{$i, $j} <= $sigmashare) {
	$sum += 1 - ($$dist{$i, $j} / $sigmashare);
      }
    }
    $sharedfitness[$i] = &scalevector($fitness[$i], 1 / $sum);
  }

  return \@sharedfitness;
}

##############################################################################
#
# Genetic operators
#
##############################################################################

# crossoverDEMC2(parent1, parent2, cr) -> children
#
# Simple crossover from ter Braak (2004): take element j from parent1 with
# probability cr, otherwise from parent2.

sub crossoverDEMC2 {
  my ($parent1, $parent2, $cr) = @_;

  my @gene1;
  my @gene2;

  for(my $j = 0; $j <= $#$parent1; $j++) {
    if(rand() < $cr) {
      $gene1[$j] = $$parent1[$j];
      $gene2[$j] = $$parent2[$j];
    }
    else {
      $gene1[$j] = $$parent2[$j];
      $gene2[$j] = $$parent1[$j];
    }
  }

  return [\@gene1, \@gene2];
}

# crossoverDEMC(parent1, parent2, cr) -> child
#
# Convenience method for crossoverDEMC2 returning just one child

sub crossoverDEMC {
  my ($parent1, $parent2, $cr) = @_;

  my $result = &crossoverDEMC2($parent1, $parent2, $cr)
  return $$result[0];
}

# crossover2(parent1, parent2) -> children
#
# Traditional crossover: choose a crossover point randomly in the genome and
# take all the elements from parent1 before that point, and all the elements
# from parent2 thereafter.

sub crossover2 {
  my ($parent1, $parent2) = @_;

  my $point = int(rand(scalar(@$parent1) + 1));

  my @child1;
  my @child2;

  for(my $i = 0; $i <= $#$parent1; $i++) {
    if($i < $point) {
      $child1[$i] = $$parent1[$i];
      $child2[$i] = $$parent2[$i];
    }
    else {
      $child1[$i] = $$parent2[$i];
      $child2[$i] = $$parent1[$i];
    }
  }

  return (\@child1, \@child2);
}

# crossover(parent1, parent2) -> child
#
# Convenience method for crossover2 returning just the first child

sub crossover {
  my ($parent1, $parent2) = @_;

  my $result = &crossover2($parent1, $parent2);
  return $$result[0];
}

# multicrossover2(parent1, parent2, prob) -> children
#
# Multipoint crossover: crossover from parent1 or parent2 each point with a
# specified probability.

sub multicrossover2 {
  my ($parent1, $parent2, $prob) = @_;

  my @child1;
  my @child2;

  my $which = rand(1) < 0.5 ? 0 : 1;
  for(my $i = 0; $i <= $#$parent1; $i++) {
    if($which == 0) {
      $child1[$i] = $$parent1[$i];
      $child2[$i] = $$parent2[$i];
    }
    else {
      $child1[$i] = $$parent2[$i];
      $child2[$i] = $$parent1[$i];
    }

    if(rand(1) < $prob) {
      $which = ($which == 1) ? 0 : 1;
    }
  }
  return [\@child1, \@child2];
}

# multicrossover(parent1, parent2, prob) -> child
#
# Convenience method for multicrossover2 returning just the first child

sub multicrossover {
  my ($parent1, $parent2, $prob) = @_;

  my $result = &multicrossover2($parent1, $parent2, $prob);
  return $$result[0];
}

# mutate(gene, mp, priors) -> mutant
#
# Mutate the gene by resampling some of its elements from their corresponding
# prior distributions.

sub mutate {
  my ($gene, $mp, $priors) = @_;

  my @mutant;

  for(my $i = 0; $i <= $#$gene; $i++) {
    $mutant[$i] = (rand() < $mp) ? &samplegene($$priors[$i], 'X') : $$gene[$i];
  }

  return \@mutant;
}

# perturb(gene, pp, amount) -> perturbed
#
# Perturb the gene a little by adding a random uniform quantity in the range
# -amount to +amount to some of its elements.

sub perturb {
  my ($gene, $types, $pp, $amount) = @_;

  my $fullyperturbed = &perturbvector($gene, $amount);
  my @perturbed;

  for(my $i = 0; $i <= $#$gene; $i++) {
    $perturbed[$i] = (rand() < $pp && $$types[$i] eq "double")
      ? $$fullyperturbed[$i] : $$gene[$i];
  }

  return \@perturbed;
}

# perturbvector(vec, amount) -> perturbed
#
# Create a new vector equal to vec + [U(-amount, +amount)]^d, where d is the
# number of dimensions of vec

sub perturbvector {
  my ($vec, $amount) = @_;

  my @ans;

  for(my $i = 0; $i <= $#$vec; $i++) {
    $ans[$i] = $$vec[$i] + &sampleuniform(-$amount, $amount);
  }

  return \@ans;
}

# perturbnormalvector(vec, var) -> perturbed
#
# Create a new vector equal to vec + [N(0, var)]^d, where d is the
# number of dimensions of vec

sub perturbnormalvector {
  my ($vec, $var) = @_;

  my @ans;

  for(my $i = 0; $i <= $#$vec; $i++) {
    $ans[$i] = $$vec[$i] + &samplenormal(0, $var);
  }

  return \@ans;
}

# normalisevector(vec, priors) -> normalised
#
# Apply normalisation parameters (if any) from the priors to a sample

sub normalisevector {
  my ($vec, $types, $priors) = @_;

  my @normalised;

  for(my $i = 0; $i <= $#$vec; $i++) {
    if($$types[$i] ne "double") {
      die "Inappropriate GA search method (DE*) used for genes with ",
	"non-double type element $$types[$i] at $i\n";
    }
    $normalised[$i] = &normalise($$vec[$i], $$priors[$i]);
  }

  return \@normalised;
}

# normalise(value, prior) -> normalised
#
# Normalise a single genome according to its prior

sub normalise {
  my ($value, $prior) = @_;

  my ($mode, $priord, $param) = &getnormparams($prior);

  if($mode eq 'none') {
    return $value;
  }
  else {
    return &normalisesample($value, $mode, $param);
  }
}

##############################################################################
#
# Sampling from priors
#
##############################################################################

# samplepop(types, priors, constraints) -> genome
#
# Sample a single member of the population from the prior distribution, given
# the constraints. See definitions for samplegene() and constrained() to find
# out more about how these are defined.

sub samplepop {
  my ($types, $priors, $constraints) = @_;

  my @genome;

  for(my $i = 0; $i <= $#$priors; $i++) {
    $genome[$i] = &samplegene($$types[$i], $$priors[$i], $$constraints[$i]);
  }

  return \@genome;
}

# samplegene($type, prior, constraint) -> sample
#
# Provide a sample for a single gene from the prior. The prior is a string
# formatted U(min,max) or N(mean,var) from which samples are taken, and
# the constraint is a satisfaction criterion for population membership,
# specifying a range the value of the gene may take (see comments to
# constrained())

sub samplegene {
  my ($type, $prior, $constraint) = @_;

  if($type eq 'double') {
    return &sampledoublegene($prior, $constraint);
  }
  elsif($type eq 'int') {
    return &sampleintgene($prior, $constraint);
  }
  elsif($type eq 'string') {
    return &samplestringgene($prior, $constraint);
  }
  die "PANIC!";
}

sub sampledoublegene {
  my ($sprior, $constraint) = @_;
  
  my ($normalise, $prior, $param)  = &getnormparams($sprior);

  my $gene;
  do {
    if($prior =~ /^U\((-?\d*\.?\d+),(-?\d*\.?\d+)\)$/) {
      $gene = &sampleuniform($1, $2);
    }
    elsif($prior =~ /^N\((-?\d*\.?\d+),(-?\d*\.?\d+)\)$/) {
      $gene = &samplenormal($1, $2);
    }
    elsif($prior =~ /^E\((-?\d*\.?\d+)\)$/) {
      $gene = &sampleexponential($1);
    }
    else {
      die "Invalid format for double prior: $prior (from $sprior)\n";
    }
    if($normalise ne 'none') {
      $gene = &normalisesample($gene, $normalise, $param);
    }
  } while(!&constrained($gene, $constraint, "double"));

  return $gene;
}

sub sampleintgene {
  my ($prior, $constraint) = @_;

  my $gene;

  do {
    if($prior =~ /^U\((-?\d+),(-?\d+)\)$/) {
      $gene = &sampleintuniform($1, $2);
    }
    elsif($prior =~ /^e\{.*\}$/) {
      my @opts = split(/,/, $1);
      $selection = &sampleintuniform(0, scalar(@opts));
      $gene = $opts[$selection];
      if($gene !~ /^-?\d+$/) {
	die "Invalid format for integer: $opts[$selection] in prior $prior\n";
      }
    }
    else {
      die "Invalid format for integer prior: $prior\n";
    }
  } while(!&constrained($gene, $constraint, "int"));
}

sub samplestringgene {
  my ($prior, $constraint) = @_;

  my $gene;

  do {
    if($prior =~ /^e\{.*\}$/) {
      my @opts = split(/,/, $1);
      $selection = &sampleintuniform(0, scalar(@opts));
      $gene = $opts[$selection];
    }
    else {
      die "Invalid format for string prior: $prior\n";
    }  
  } while(!&constrained($gene, $constraint, "string"));
}

# sampleuniform(min, max) -> sample
#
# Return a sample from a uniform distribution.

sub sampleuniform {
  my ($min, $max) = @_;

  die "Invalid uniform sample range U($min,$max)\n" if($max < $min);

  return (rand() * ($max - $min)) + $min;
}

sub sampleintuniform {
  my ($min, $max) = @_;

  die "Invalid uniform sample range U($min,$max)\n" if($max < $min);

  return $min + int(rand($max - $min));
}

# samplenormal(mean, var) -> sample
#
# Return a sample from a normal distribution, using the Box-Muller 
# transform.

BEGIN {
  # This is the Perl idiom for the equivalent in C of static variables in
  # function definition:

  my $normalsampleswitch;
  my $savednormalsample;


  sub samplenormal {
    my ($mean, $var) = @_;

    if($normalsampleswitch) {
      $normalsampleswitch = 0;
      return (sqrt($var) * $savednormalsample) + $mean;
    }

    my $sample1 = rand();
    $sample1 = 1 if $sample1 == 0;

    my $sample2 = rand();
    $sample2 = 1 if $sample2 == 0;

    $normalsampleswitch = 1;
    $savednormalsample = sqrt(-2.0 * log($sample1)) * sin(pi * 2 * $sample2);

    return (sqrt($var) * sqrt(-2.0 * log($sample1))
	    * cos(pi * 2 * $sample2)) + $mean;
  }
}

# sampleexponential(lambda) -> sample
#
# Return a sample from an exponential distribution

sub sampleexponential {
  my ($lambda) = @_;

  my $usample = rand();
  $usample = 1 if $usample == 0;
  return (-log($usample)) / $lambda;
}

# normalisesample(value, method, nparam) -> normalised sample
#
# Use various methods to impose bounds on samples mathematically. This is
# useful e.g. when sampling from a normal distribution.

sub normalisesample {
  my ($value, $method, $nparam) = @_;
  
  if($method eq 'none') {
    return $value;
  }
  if($method eq 'T' || $method eq 'S' || $method eq 'M') {
    my($min, $max) = @$nparam;

    if($min >= $max) {
      die "Invalid normalisation parameters for sigmoid: ($min, $max)\n";
    }

    if($method eq 'T') {
      return $min + (0.5 + ((($max - $min) / 2) * tanh($value)));
    }
    elsif($method eq 'M') {
      return ($value < $min) ? $min : (($value > $max) ? $max : $value);
    }
    else {
      return $min + (($max - $min) / (1.0 + exp(-$value)));
    }
  }
  if($method eq 'LV' || $method eq 'LE' || $method eq 'Le') {
    my($min) = @$nparam;

    if($method eq 'LV') {
      return $min + abs($value);
    }
    elsif($method eq 'Le') {
      return $min + exp(-$value);
    }
    else {
      return $min + exp($value);
    }
  }
  elsif($method eq 'UV' || $method eq 'UE' || $method eq 'Ue') {
    my($max) = @$param;

    if($method eq 'UV') {
      return $max - abs($value);
    }
    elsif($method eq 'Ue') {
      return $max - exp(-$value);
    }
    else {
      return $max - exp($value);
    }
  }

  die "Invalid normalisation method: $method\n";
}

# constrained(value, constraint) -> boolean
#
# Return 1 if the value is constrained by the constraint, and 0 otherwise.
# The constraint has the format 'none' or 'X' if there are no constraints,
# otherwise <fp><cmpl>X<cmpl><fp>, X<cmpl><fp>, or X<cmpg><fp>, where <cmpl>
# is one of < or <=, <cmpg> one of > or >=, and <fp> is a floating point
# number (without scientific notation).

sub constrained {
  my ($value, $constraint, $type) = @_;

  return 1 if($constraint eq 'none' || $constraint eq 'X');

  if($constraint !~ /^(-?\d*\.?\d+<=?)?X(<=?-?\d*\.?\d+)?$/
     && $constraint !~ /^X>=?-?\d*\.?\d+$/
     && $constraint !~ /^X-?e\{.+\}$/)
    ) {
    die "Invalid constraint format: $constraint\n";
  }

  if($constraint =~ /^Xe\{(.+)\}$/) {
    my @opts = split(/,/, $1);
    foreach my $opt (@opts) {
      return 1 if(($value eq $opt && $type eq 'string')
		  || ($value == $opt && $type ne 'string'));
    }
    return 0;
  }
  elsif($constraint =~ /^X-e\{(.+\}$/) {
    my @opts = split(/,/, $1);
    foreach my $opt (@opts) {
      return 0 if(($value eq $opt && $type eq 'string')
		  || ($value == $opt && $type ne 'string');
    }
    return 1;
  }

  die "Invalid constraint for string type $constraint" if $type eq 'string';
  die "Invalid constraint for int type $constraint" if($type eq 'int'
						       && $constraint =~ /\./);
    
  return 0 if($constraint =~ /X<(-?\d*\.?\d+)$/ && $value >= $1);
  return 0 if($constraint =~ /X<=(-?\d*\.?\d+)$/ && $value > $1);

  return 0 if($constraint =~ /^(-?\d*\.?\d+)<X/ && $value <= $1);
  return 0 if($constraint =~ /^(-?\d*\.?\d+)<=X/ && $value < $1);

  return 0 if($constraint =~ /^X>(-?\d*\.?\d+)$/ && $value <= $1);
  return 0 if($constraint =~ /^X>=(-?\d*\.?\d+)$/ && $value < $1);

  return 1;
}

# constrainedall(sample, constraints) -> boolean
#
# Check whether a whole sample is constrained as specified

sub constrainedall {
  my ($sample, $constraints) = @_;

  for(my $i = 0; $i <= $#$sample; $i++) {
    return 0 if(!&constrained($$sample[$i], $$constraints[$i]));
  }

  return 1;
}

# constrainednall(pop, constraints) -> boolean
#
# Check whether a population of samples is constrained as specified

sub constrainednall {
  my ($pop, $constraints) = @_;

  for(my $i = 0; $i <= $#$pop; $i++) {
    return 0 if(!&constrainedall($$pop[$i], $constraints));
  }

  return 1;
}

##############################################################################
#
# Hall of fame
#
##############################################################################

# maintainhalloffame(halloffame, population, fitness, gen, param) -> ntrans
#
# Keep a record of all the best samples found, their fitness, and the
# generation they were first discovered. Return the number of members of the
# population transferred to the hall of fame.
#
# This method works by finding the pareto front in the current hall of fame
# and the population taken together. The hall of fame is then made to consist
# of at least that pareto front. If the size of the pareto front is less than
# the size of the hall of fame, then old members of the hall of fame are
# retained.

sub maintainhalloffame {
  my ($halloffame, $population, $fitness, $gen, $param, $identifiers) = @_;

  # Build arrays containing all information about the population and the
  # hall of fame

  my @wholepopulation;
  my @wholefitness;
  my @wholegen;
  my @wholeid;

  my $i;
  for(my $j = 0, $i = 0; $j <= $#$population; $j++, $i++) {
    push(@wholepopulation, $$population[$j]);
    push(@wholefitness, $$fitness[$j]);
    push(@wholegen, $gen);
    push(@wholeid, $$identifiers[$j]);
  }

  my $hofstart = $i;		# Remember where we started adding the hall
				# of fame

  for(my $j = 0; $j <= $#$halloffame; $j++) {
    push(@wholepopulation, $$halloffame[$j][0]);
    push(@wholefitness, $$halloffame[$j][1]);
    push(@wholegen, $$halloffame[$j][2]);
    push(@wholeid, $$halloffame[$j][3]);
  }

  # Get the pareto front of the hall of fame union the population

  my @front = &shuffle(&paretofront(\@wholefitness, ()));
				# Shuffle the front so when members are
				# removed from the hall of fame there is no
				# bias
  my @fitnessfront;
  for(my $j = 0; $j <= $#front; $j++) {
    $fitnessfront[$j] = $wholefitness[$front[$j]];
  }

  # Make sure the hall of fame directory is there if required

  if($keephof && !-e "$wd/hof") {
    mkdir("$wd/hof") or die "Cannot create directory $wd/hof: $!\n";
  }

  # Find out the number of members of the front that are in the hall of fame
  # and remember which they are

  my $ninhof = 0;
  my %inhof;
  for(my $k = 0; $k <= $#front; $k++) {
    if($front[$k] >= $hofstart) {
      $ninhof++;
      my $hofref = $front[$k] - $hofstart;
      $inhof{$hofref} = $k;
    }
  }

  # Calculate the hall of fame size. This will be bigger than the 'keep'
  # parameter if the latter is smaller than the size of the pareto front

  my $nhalloffame = (defined($$param{'keep'})
		     ? $$param{'keep'}
		     : scalar(@$population));

  $nhalloffame = scalar(@front) if scalar(@front) > $nhalloffame;

  # Remove members of the hall of fame from the front of the array unless
  # they are in the pareto front, until the hall of fame is small enough
  # to add members of the population in the pareto front to the hall of fame

  $i = 0;
  my @halloffamefront;
  while(scalar(@$halloffame) + scalar(@front)
	+ scalar(@halloffamefront) - $ninhof > $nhalloffame) {
    my $hofmember = shift(@$halloffame);
    if(!defined($inhof{$i})) {
      &rm("$wd/hof/$$hofmember[3]") if $keephof;
    }
    else {
      push(@halloffamefront, $hofmember);
    }
    $i++;
  }
  unshift(@$halloffame, @halloffamefront);

  # Add members of the population in the pareto front to the hall of fame,
  # keeping track of which and how many there were

  my %transhof;
  my $ntrans = 0;
  for(my $k = 0; $k <= $#front; $k++) {
    if($front[$k] < $hofstart) {
      &mvhof($$identifiers[$front[$k]]) if $keephof;
      $transhof{$front[$k]} = $front[$k];
      $ntrans++;

      push(@$halloffame, [$$population[$front[$k]],
			  $$fitness[$front[$k]],
			  $gen, $$identifiers[$front[$k]]]);
    }
  }

  # Remove data stored for members of the population not in the hall of fame,
  # if required

  if($keephof) {
    for(my $j = 0; $j <= $#$identifiers; $j++) {
      &rm("$wd/$$identifiers[$j]") unless defined($transhof{$j});
    }
  }

  # Return the number of members of the population transferred to the hall of
  # fame

  return ($ntrans, \@fitnessfront);
}

# mvhof(identifer)
#
# Save a run to the hall of fame

sub mvhof {
  my ($identifier) = @_;

  my $hofname = "$wd/hof/$identifier";
  my $c = -1;
  while(-e "$hofname") {
    $c++;
    $hofname = "$wd/hof/$identifier-$c";
  }
  &mv("$wd/$identifier", $hofname);
}

##############################################################################
#
# C A L L I N G   O T H E R   S C R I P T S
#
##############################################################################

##############################################################################
#
# Model runs
#
##############################################################################

# waitforruns(identifers)
#
# Wait for all runs to terminate. In case it helps, a list of identifiers
# is passed as argument

sub waitforruns {
  my ($identifiers) = @_;

  &wait(1);
}

# getdatetime()
#
# Return the date and time as a string to use in an identifier

sub getdatetime() {
  my ($s, $mi, $h, $d, $mo, $y) = localtime(time());

  $mo++;
  $y %= 100;
  
  return sprintf("%02d%02d%02d%02d%02d%02d", $y, $mo, $d, $h, $mi, $s);
}

{
  my %children;			# Local variable for startrun and wait
  my %exitstatus;		# Local variable for wait and runfitness

  # startrun(modelScript, search, sample) -> run ID
  # 
  # Fork to start a run, waiting until there's a spare slot

  sub startrun {
    my ($modelScript, $search, $sample) = @_;

    &wait($maxproc);
  FORK:
    {
      my $dt = &getdatetime();
      my $pid;
      if($pid = fork()) {	# parent
	&log("Sample", &popstr($sample, $search),
	     "process $pid stored in directory $wd/$dt-$pid");
	$children{$pid} = "$wd/$dt-$pid";
	return "$dt-$pid";
      }
      elsif(defined($pid)) {	# child
	&run("$wd/$dt-$$", $modelScript, $search, $sample);
	exit 1;			# shouldn't get here
      }
      elsif($! == EAGAIN) {
	sleep 5;
	redo FORK;
      }
      else {
	die "Can't fork: $!\n";
      }
    }
  }
  
  # wait(max_nchildren)
  #
  # Wait until the number of child processes is less than the argument

  sub wait {
    my ($max_nchildren) = @_;
    
    while(scalar(keys(%children)) >= $max_nchildren) {
      my $pid = wait();
      if($pid != -1 && defined($children{$pid})) {
	$exitstatus{$children{$pid}} = $?;
	&log("Run $pid stopped with exit status $?");
	delete $children{$pid};
      }
      elsif($pid == -1) {
	die "Expecting ", scalar(keys(%children)), " child processes, but ",
	"there don't seem to be any\n";
      }
      elsif(!defined($children{$pid})) {
	warn "Child process $pid is not one I knew about!\n";
      }
    }
  }
  
  # runfitness(pid, fitnessScript)
  # 
  # Compute the run fitness. 

  sub runfitness {
    my ($id, $fitnessScript, $dir2ix, $identifiers, $fitness) = @_;

    my $rundir = "$wd/$id";

    open(FITNESS, ">", "$rundir/fitness.txt");
    
    print FITNESS $exitstatus{$id}, "\n";

    close(FITNESS);

    &startfit($fitnessScript, $rundir, "fitness.txt",
	      $dir2ix, $identifiers, $fitness);
  }
}

# run(rundir, modelScript, search, sample)
#
# Prepare the files in the working directory and run the SPOMM

sub run {
  my ($rundir, $modelScript, $search, $sample) = @_;

  my $input = &preparefiles($rundir, $search, $sample);
  chdir $rundir or die "Cannot cd to $rundir: $!";
  exec "$modelScript $input > stdout-$$.txt 2> stderr-$$.txt";
  die "exec $modelScript $input from $rundir failed: $!\n";
}

# preparefiles(rundir, search, sample)
#
# rundir (scalar): directory to run the experiment from, not created.
#
# search (array): array of parameters to search
#
# sample (array): array of parameters in the gene, the length of which
#        should be the same as the length of the search arras.

sub preparefiles {
  my ($rundir, $search, $sample) = @_;

  if(!-e "$rundir") {
    mkdir($rundir) || die "Cannot create directory $rundir: $!\n";
  }
  else {
    # This actually isn't very helpful unless the new directory
    # is returned as a different identifier for the population
    # member somehow. Hopefully this will not happen now that
    # the date and time are included in the directory name.
    my $kk = 0;
    while(-e "$rundir-$kk") {
      $kk++;
    }
    &mv($rundir, "$rundir-$kk");
    mkdir($rundir) || die "Cannot create directory $rundir: $!\n";
  }

  open(GENE, ">", "$rundir/gene.csv")
    or die "Cannot create gene file gene.csv in directory $rundir: $!\n"

  for(my $i = 0; $i <= $#$search; $i++) {
    print GENE "$$search[$i],$$sample[$i]\n";
  }
  close(GENE);

  return "gene.csv";
}

##############################################################################
#
# Fitness
#
##############################################################################

{
  my %fitchildren;	     # Local variable for startfit and waitfit

  # startfit(fitnessScript, dir, fitnessFile) -> fitness ID
  #
  # Fork to start computing fitness

  sub startfit {
    my ($fitnessScript, $dir, $fitnessFile,
	$dir2ix, $identifers, $fitness) = @_;

    &waitfit($maxproc, $dir2ix, $identifiers, $fitness);

  FORK:
    {
      my $dt = &getdatetime();
      my $pid;
      if($pid = fork()) {	# parent
	&log("Fitness for $fitnessFile in $dir: ",
	     "process $pid stored in directory $dir");
	$fitchildren{$pid} = "$dir";
	return "$dir";
      }
      elsif(defined($pid)) {	# child
	&runfit($dir, $fitnessScript, $fitnessFile);
	exit 1;			# shouldn't get here
      }
      elsif($! == EAGAIN) {
	sleep 5;
	redo FORK;
      }
      else {
	die "Can't fork: $!\n";
      }
    }

  }

  # waitfit(max_nchildren)
  #
  # Wait until the number of child processes is less than the argument

  sub waitfit {
    my ($max_nchildren, $dir2ix, $identifiers, $fitness) = @_;
    
    while(scalar(keys(%fitchildren)) >= $max_nchildren) {
      my $pid = wait();
      if($pid != -1 && defined($fitchildren{$pid})) {
	my $rundir = $fitchildren{$pid};
	&log("Fitness computation $pid stopped with exit status $?");
	if($? != 0) {
	  die "Exit status $? computing fitness in run directory $rundir\n";
	}
	delete $fitchildren{$pid};

	# Read the fitness file

	if(!defined($$dir2ix{$rundir})) {
	  &log("Bug: No population index for run directory $rundir");
	  die "Cannot find population index for fitness computation in run ",
	    "directory $rundir\n";
	}
	my $pop = $$dir2ix{$rundir};

	my @thisfit;
	open(FIT, "<", "$rundir/fitness.txt")
	  or die "Cannot read $rundir/fitness.txt: $!\n";
	while(my $line = <FIT>) {
	  $line =~ s/\#.*$//;	# Allow comments in fitness file
	  $line =~ s/\s+$//;
	  push(@thisfit, $line);
	}
	close(FIT);

	$$fitness[$pop] = \@thisfit;
	&log("Fitness of run $$identifiers[$pop] is",
	     &fitnessstr($$fitness[$pop]));

	# Remove the directory if required

	if($delete) {
	  &rm($rundir);
	}

      }
      elsif($pid == -1) {
	die "Expecting ", scalar(keys(%fitchildren)), " child processes, ",
	  "but there don't seem to be any\n";
      }
      elsif(!defined($fitchildren{$pid})) {
	warn "Child process $pid is not one I knew about!\n";
      }
    }
  }
}

# runfit(rundir, fitnessScript, fitnessFile)
#
# Compute the fitness for a run

sub runfit {
  my ($rundir, $fitnessScript, $fitnessFile) = @_;

  chdir $rundir or die "Cannot cd to $rundir: $!";
  exec "$fitnessScript $fitnessFile > stdout-fit-$$.txt 2> stderr-fit-$$.txt";
  die "exec $fitnessScript $fitnessFile from $rundir failed: $!\n";
}

##############################################################################
#
# V E C T O R   A N D   M A T R I X   A R I T H M E T I C
#
##############################################################################

# distancematrix(fitness, norm) -> distance matrix

sub distancematrix {
  my ($fitness, $norm) = @_;
  
  my %distance;

  for(my $i = 0; $i < $#$fitness; $i++) {
    $distance{$i, $i} = 0;
    for(my $j = $i + 1; $j <= $#fitness; $j++) {
      $distance{$i, $j} = &normvector($$fitness[$i], $$fitness[$j], $norm);
      $distance{$j, $i} = $distance{$i, $j};
    }
  }

  return \%distance;
}

# subvector(vec1, vec2) -> difference
#
# Create a new vector equal to vec1 - vec2, which are assumed to be of the
# same dimensionality.

sub subvector {
  my ($vec1, $vec2) = @_;

  my @ans;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    $ans[$i] = $$vec1[$i] - $$vec2[$i];
  }
  
  return \@ans;
}

# addvector(vec1, vec2) -> added
#
# Create a new vector equal to vec1 + vec2, which are assumed to be of the
# same dimensionality.

sub addvector {
  my ($vec1, $vec2) = @_;

  my @ans;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    $ans[$i] = $$vec1[$i] + $$vec2[$i];
  }

  return \@ans;
}

# mulvector(vec1, vec2) -> dot product
#
# Return the dot product of the two vectors

sub mulvector {
  my ($vec1, $vec2) = @_;

  my $ans = 0;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    $ans += $$vec1[$i] * $$vec2[$i];
  }

  return $ans;
}

# normvector(vec1, vec2, norm) -> distance
#
# norm is a number or the string 'inf', and is 2 for Euclidean distance by
# default.

sub normvector {
  my ($vec1, $vec2, $norm) = @_;

  if(!defined($norm)) {
    $norm = 2;			# L2 norm -- Euclidean distance
  }
  
  my $distance = 0;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    my $abs = abs($$vec1[$i] - $$vec2[$i]);

    if($norm eq "inf") {
      $distance = ($abs > $distance) ? $abs : $distance;
    }
    else {
      $distance += $abs ** $norm;
    }
  }

  if($norm ne "inf") {
    $distance = $distance ** (1 / $norm);
  }

  return $distance;
}

# meanratiovector(vec1, vec2) -> mean ratio
#
# Return the mean ratio of the elements of the two vectors

sub meanratiovector {
  my ($vec1, $vec2) = @_;

  my $tratio = 0;
  my $n = 0;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    $tratio += $$vec1[$i] / $$vec2[$i];
    $n++;
  }

  return $tratio / $n;
}

# lengthratiovector(vec1, vec2) -> length of the vector of ratios
#
# Return the length of the vector of ratios

sub lengthratiovector {
  my ($vec1, $vec2) = @_;

  my $ssratio = 0;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    my $ratio = $$vec1[$i] / $$vec2[$i];
    $ssratio += $ratio * $ratio;
  }

  return sqrt($ssratio);
}

# cmpvector(vec1, vec2) -> comparison
#
# Return a comparison of two vectors. This is -1 if all elements of vec1 are
# less than or equal to their corresponding element in vec2; +1 if the relation
# is greater than or equal to; and 0 if the vectors are equal or incomparable.
# This method may not be suitable for using in sorting algorithms, as the
# semantics of a zero return value would break the properties of == (i.e. that
# if A == B and A == C then B == C; A could be incomparable to B and C, and 
# B > C, say)

sub cmpvector {
  my ($vec1, $vec2) = @_;

  my $ans = pocmpvector($vec1, $vec2);
  return $ans eq 'incomparable' ? 0 : $ans;
}

# pocmpvector(vec1, vec2) -> comparison
#
# Returns a partial order comparison of two vectors. If all elements of vec1
# are equal to their corresponding element in vec2, 0 is returned; if all
# elements of vec1 are greater than or equal to their corresponding element
# in vec2 then +1; if less than, -1. Otherwise, the string 'incomparable'
# is returned.

sub pocmpvector {
  my ($vec1, $vec2) = @_;

  my $ans = 0;
  for(my $i = 0; $i <= $#$vec1; $i++) {
    # Handle non-numeric fitnesses
    my $cmp;
    if($vec1[$i] !~ /\d/ || $vec2[$i] !~ /\d/) {
      $cmp = $$vec1[$i] cmp $$vec2[$i];
    }
    else {
      $cmp = $$vec1[$i] <=> $$vec2[$i];
    }
    if(($ans < 0 && $cmp > 0) || ($ans > 0 && $cmp < 0)) {
      return 'incomparable';
    }
    elsif($ans == 0) {
      $ans = $cmp;
    }
  }

  return $ans;
}

# scalevector(vec, scale) -> scaled
#
# Create a new vector equal to scale * vec

sub scalevector {
  my ($vec, $scale) = @_;

  my @ans;

  for(my $i = 0; $i <= $#$vec; $i++) {
    $ans[$i] = $scale * $$vec[$i];
  }

  return \@ans;
}

# eqvector(vec1, vec2) -> boolean
#
# Return whether or not the two vectors (assumed to have the same number of
# dimensions) are numerically equal.

sub eqvector {
  my ($vec1, $vec2) = @_;

  for(my $i = 0; $i <= $#$vec1; $i++) {
    return 0 if($$vec1[$i] != $$vec2[$i]);
  }

  return 1;
}

##############################################################################
#
# F I L E   I / O
#
##############################################################################

##############################################################################
#
# String parsers and generators
#
##############################################################################

# popstr(sample, search) -> string
#
# Return a string containing the state of the population

sub popstr {
  my ($sample, $search) = @_;

  my $str = "[";
  my $i;
  for($i = 0; $i <= $#$search; $i++) {
    $str .= ", " if $i > 0;
    $str .= "$$search[$i] = $$sample[$i]";
  }
  $str .= "]";

  return $str;
}

# parsepopstr(str) -> sample
#
# Return a reference to an array containing the state of the population

sub parsepopstr {
  my ($str) = @_;

  my @sample;

  if($str =~ /^\[.*\]$/) {
    $str = $1;
  }
  else {
    die "Invalid population string: $str\n";
  }
  $str =~ s/\s//g;
  my @samplestr = split(/,/, $str);
  for(my $i = 0; $i <= $#samplestr; $i++) {
    my ($search, $value) = split(/=/, $samplestr[$i]);

    if(!defined($value) || $value eq "") {
      die "Invalid sample string for population: $samplestr[$i]\n";
    }
    push(@sample, $value);
  }

  return \@sample;
}

# frontstr(front) -> string
#
# Return a formatted string of a pareto front of fitnesses

sub frontstr {
  my ($front) = @_;

  my $str = "{";
  for(my $i = 0; $i <= $#$front; $i++) {
    $str .= "; " if $i > 0;
    $str .= &fitnessstr($$front[$i]);
  }
  $str .= "}";

  return $str;
}

# fitnessstr(fitness) -> string
#
# Return a string containing a printable fitness

sub fitnessstr {
  my ($fitness) = @_;

  my $str = "(";
  for(my $i = 0; $i <= $#$fitness; $i++) {
    $str .= ", " if $i > 0;
    $str .= "$$fitness[$i]";
  }
  $str .= ")";

  return $str;
}

# parsefitnessstr(str) -> fitness
#
# Return a reference to a fitness array parsed from a string

sub parsefitnessstr {
  my ($str) = @_;

  if($str =~ /^\(.*\)$/) {
    $str = $1;
  }
  else {
    die "Invalid fitness string: $str\n";
  }
  $str =~ s/\s//g;
  my @fitness = split(/,/, $str);

  return \@fitness;
}

# getnormparams(prior) -> (mode, prior, param)
#
# Extract the normalisation mode and parameters for it from the prior,
# and return the contained prior too

sub getnormparams {
  my ($prior) = @_;

  my $normalise = 'none';
  my @normalparam;

  my $priord = $prior;

  if($prior =~ /^([STM])\[(.*);(-?\d*\.?\d+);(-?\d*\.?\d+)\]$/) {
    $normalise = $1;
    $priord = $2;
    push(@normalparam, $3, $4);
  }
  elsif($prior =~ /([UL][VEe])\[(.*);(-?\d*\.?\d+)\]$/) {
    $normalise = $1;
    $priord = $2;
    push(@normalparam, $3);
  }

  return($normalise, $priord, \@normalparam);
}

##############################################################################
#
# Population and other files saved by this program
#
##############################################################################

# savega(wd, population, fitness, identifiers, argv, search, biophysfiles)
#
# Save the GA's state to a file

sub savega {
  my ($wd, $population, $fitness, $identifiers,
      $argv, $search) = @_;

  my $statefile = "$wd/state-$$.txt";

  open(STATE, ">$statefile")
    or die "Cannot create state file $statefile: $!\n";

  print STATE "CWD\n";
  print STATE getcwd(), "\n";
  print STATE "$wd\n";

  print STATE "ARGV\n";
  for(my $i = 0; $i <= $#$argv; $i++) {
    print STATE "$$argv[$i]\n";
  }
  print STATE "POPULATION\n";
  for(my $i = 0; $i <= $#$population; $i++) {
    my $popstr = &popstr($$population[$i], $search);
    my $fitstr = &fitnessstr($$fitness[$i]);
    print STATE "$$identifiers[$i]: $popstr : $fitstr\n";
  }
}

##############################################################################
#
# Parameter, population and configuration input files
#
##############################################################################

# loadga(file, population, fitness, identifiers, argv) -> cwd
#
# Load the GA's state from a file

sub loadga {
  my ($file, $population, $fitness, $identifiers, $argv) = @_;

  open(STATE, "<$file") or die "Cannot read state file $file: $!\n";

  # Read the cwd

  my $line = <STATE>;
  chomp $line;
  if($line ne 'CWD') {
    die "Error in state file $file: Expecting CWD, found $line\n";
  }
  my $cwd = <STATE>;
  chomp $cwd;
  my $wd = <STATE>;
  chomp $wd;

  # Read the argv

  $line = <STATE>;
  chomp $line;
  if($line ne 'ARGV') {
    die "Error in state file $file: Expecting ARGV, found $line\n";
  }
  while($line = <STATE>) {
    chomp $line;
    last if $line eq 'POPULATION';
    push(@$argv, $line);
  }

  # Read the population

  while($line = <STATE>) {
    chomp $line;
    if($line =~ /^(.*): (.*) : (.*)$/) {
      my $id = $1;
      my $popstr = $2;
      my $fitstr = $3;
      
      push(@$identifiers, $id);
      push(@$population, &parsepopstr($popstr));
      push(@$fitness, &parsefitnessstr($popstr));
    }
    else {
      die "Error in state file $file: Expecting population data, found ",
      "$line\n";
    }
  }

  return ($cwd, $wd);
}

# readga(paramFile, gafile)
#
# The GA file contains parameters for the GA, arranged as follows:
#
# population <population>
# generations <generations>
# rule <rule>
# parameters {
#   <param name> = <param value>
# }
# run-cfg {
#   <param name> = <param value>
# }
# fitness-cfg {
#   <param name> = <param value>
# }
#
# The run-cfg and fitness-cfg sections are optional, and allow
# configuration options to be passed to the model run and fitness
# scripts using the -config argument (which they are expected to
# accept).
#
# The parameter file describes the parameters being searched. For each
# parameter there is a name, something describing the set of values it
# can take, something describing the prior.
# 
# parameter {
#   name: <name>
#   type: <int|double|string>
#   constraint: <constraint>
#   prior: <prior>
# }

sub readga {
  my ($paramfile, $gafile) = @_;

  open(GA, "<", "$gafile") or die "Cannot open GA file $gafile: $!\n";
  
  my $npop = &readnpop(*GA, $gafile);
  my $ngen = &readngen(*GA, $gafile);
  my $rule = &readrule(*GA, $gafile);
  my %param = &readparam(*GA, $gafile, "parameters", "breeding rule", 0);
  my %modelcfg = &readparam(*GA, $gafile, "run-cfg", "run configuration", 1);
  my %fitcfg = &readparam(*GA, $gafile, "fitness-cfg", "fitness configuration",
			  1);
  my @search;
  my @types;
  my @priors;
  my @constraints;

  close(GA);

  my @paramtxt;
  while(my ($key, $value) = each(%param))  {
    push(@paramtxt,"$key = $value");
  }

  &readsearchparam($paramfile, \@search, \@types, \@priors,
		   \@constraints);

  &log("population size $npop, number of generations $ngen, rule $rule",
       join(", ", @paramtxt), "-- searching", join(", ", @search),
       "constraints", join(", ", @constraints), "priors",
       join(", ", @priors));

  return ($npop, $ngen, $rule, \%param, \@search, \@types, \@priors,
	  \@constraints, \%modelcfg, \%fitcfg);
}

# readnpop(fp, gafile)
#
# Read the population size from the GA file pointer

sub readnpop {
  my ($fp, $gafile) = @_;

  my $line = <$fp>;
  if(!$line) {
    die "Unexpected EOF in GA file $gafile while reading population size\n";
  }
  chomp $line;
  if($line =~ /^population\s+(\d+)$/) {
    return $1;
  }
  else {
    die "Error in GA file $gafile: expecting \"population N\" found $line\n";
  }
}

# readngen(fp, gafile)
#
# Read the number of generations from the GA file pointer

sub readngen {
  my ($fp, $gafile) = @_;

  my $line = <$fp>;
  if(!$line) {
    die "Unexpected EOF in GA file $gafile while reading number of ",
    "generations\n";
  }
  chomp $line;
  if($line =~ /^generations\s+(\d+)$/) {
    return $1;
  }
  else {
    die "Error in GA file $gafile: expecting \"generations N\" found $line\n";
  }
}

# readrule(fp, gafile)
#
# Read the rule from the GA file pointer

sub readrule {
  my ($fp, $gafile) = @_;

  my $line = <$fp>;
  if(!$line) {
    die "Unexpected EOF in GA file $gafile while reading breeding rule\n";
  }
  chomp $line;
  if($line =~ /^rule\s+(\S+)$/) {
    return $1;
  }
  else {
    die "Error in GA file $gafile: expecting \"rule S\" found $line\n";
  }
}

# readparam(fp, gafile)
#
# Read the GA rule parameters from the GA file pointer

sub readparam {
  my ($fp, $gafile, $section, $sectionname, $optional) = @_;

  my %param;
  my $curpos = tell($fp);
  my $line = <$fp>;
  if(!$line) {
    return %param if($optional);
    die "Unexpected EOF in GA file $gafile while reading $sectionname\n";
  }
  chomp $line;
  if($line !~ /^$section\s+\{$/) {
    seek($fp, $curpos, 0);
    if($optional) {
      warn "GA file $gafile contains no section \"$section {\" where it is ",
	"optionally expected; got $line instead\n";
      return %param;
    }
    die "Error in GA file $gafile: expecting \"$section {\" found $line\n";
  }
  while($line = <$fp>) {
    chomp $line;
    last if($line eq '}');
    my @words = split(" ", $line);
    if($words[1] ne '=' || scalar(@words) != 3) {
      die "Error in GA file $gafile: expecting \"<param> = <value>\" found ",
      "$line\n";
    }
    $param{$words[0]} = $words[2];
  }
  if($line ne '}') {
    die "Error in GA file $gafile: expecting \"}\", found EOF\n";
  }
  return %param;
}

# readsearchparam(paramfile, search, types, priors, constraints)
#
# Read search parameters from the parameter file
#
# The parameter file describes the parameters being searched. For each
# parameter there is a name, something describing the set of values it
# can take, something describing the prior.
# 
# parameter {
#   name: <name>
#   type: <int|double|string>
#   constraint: <constraint>
#   prior: <prior>
# }

sub readsearchparam {
  my ($paramfile, $search, $types, $priors, $constraints) = @_;

  open(FP, "<", $paramfile)
    or die "Cannot open search parameter file $paramfile: $!\n";
  my $line = <FP>;
  if(!$line) {
    die "Unexpected EOF in search parameter file $paramfile while reading ",
      "search parameters\n";
  }
  chomp $line;
  if($line !~ /^search\s+\{$/) {
    die "Error in search parameter file $paramfile: expecting \"search {\" ",
      "found $line\n";
  }

  while($line = <FP>) {
    chomp $line;
    last if $line eq '}';
    if($line !~ /^\s*parameter\s+\{$/) {
      die "Error in search parameter file $paramfile: expecting \"parameter {",
	"\" found $line\n";
    }
    my $gotname = 0;
    my $gottype = 0;
    my $gotconstraint = 0;
    my $gotprior = 0;
    while($line = <FP>) {
      chomp $line;
      $line =~ s/^\s*//;
      last if $line =~ /^\}$/;
      my @words = split(" ", $line);
      if($words[0] eq 'name:') {
	if($gotname) {
	  die "Already have name $search[$#search] for parameter in search ",
	    "parameter file $paramfile: \"$line\"\n";
	}
	$gotname = 1;
	push(@$search, $words[1]);
      }
      elsif($words[0] eq 'type:') {
	if(!$gotname) {
	  die "Expecting \"name:\" got \"type:\" in search parameter file ",
	    "$paramfile\n";
	}
	if($gottype) {
	  die "Already have type $types[$#types] for parameter ",
	    "$search[$#search] in search parameter file $paramfile: ",
	    "\"$line\"\n";
	}
	if($words[1] ne "int" && $words[1] ne "double"
	   && $words[1] ne "string") {
	  die "Type must be int, double or string in search parameter file ",
	    "$paramfile, parameter $search[$#search]\n";
	}
	$gottype = 1;
	push(@$types, $words[1]);
      }
      elsif($words[0] eq 'constraint:') {
	if(!$gottype) {
	  die "Expecting \"type:\" got \"constraint:\" in search parameter ",
	    "file $paramfile, parameter $search[$#search]\n";
	}
	if($gotprior) {
	  die "\"constraint:\" must appear before \"prior:\" in search ",
	    "parameter file $paramfile, parameter $search[$#search]\n";
	}
	if($gotconstraint) {
	  die "Already have constraint $constraints[$#constraints] for ",
	    "parameter $search[$#search] in search parameter file ",
	    "$paramfile: \"$line\"\n";
	}

	$gotconstraint = 1;
	push(@$constraints, $words[1]);
      }
      elsif($words[0] eq 'prior:') {
	if(!$gottype) {
	  die "Expecting \"type:\" got \"prior:\" in search parameter ",
	    "file $paramfile, parameter $search[$#search]\n";
	}
	if($gotprior) {
	  die "Already have prior $priors[$#priors] for ",
	    "parameter $search[$#search] in search parameter file ",
	    "$paramfile: \"$line\"\n";
	}
	if(!$gotconstraint) {
	  $gotconstraint = 1;
	  push(@$constraints, "none");
	}
	$gotprior = 1;
	push(@$priors, $words[1]);
      }
      else {
	if(!$gotname) {
	  die "Expecting \"name:\" got \"$words[0]\" in search parameter file",
	    " $paramfile\n";
	}
	if(!$gottype) {
	  die "Expecting \"type:\" got \"$words[0]\" for parameter ",
	    "$search[$#search] in search parameter file $paramfile\n";
	}
	if(!$gotconstraint || !$gotprior) {
	  die "Expecting \"constraint:\" or \"prior:\" got \"$words[0]\" ",
	    "for parameter $search[$#search] in search parameter file ",
	    "$paramfile\n";
	}
	die "Line \"$line\" unexpected in search parameter file $paramfile\n";
      }
    }
    if(!$gotname) {
      die "No \"name:\" after \"parameter {\" in search parameter file ",
	"$paramfile\n";
    }
    elsif(!$gotprior) {
      # If they have a prior, then they must have a type and a constraint
      # by the other error messages
      die "No \"prior:\" for parameter $search[$#search] in search parameter ",
	"file $paramfile\n";
    }
    if(scalar(@$search) != scalar(@$types)
       || scalar(@$search) != scalar(@$constraints)
       || scalar(@$search) != scalar(@$priors)) {
      die "Somehow the numbers of parameter names (", scalar(@$search), "), ",
	"types (", scalar(@$types), "), constraints (", scalar(@$constraints),
	") and priors (", scalar(@$priors), ") are not all equal after ",
	"reading parameter $search[$#search] in search parameter file ",
	"$paramfile\n";
    }
  }

  if($line ne '}') {
    die "Error in search parameter file $paramfile: expecting \"}\" found ",
      "EOF\n";
  }

  close(FP);
}

##############################################################################
#
# U T I L I T I E S
#
##############################################################################

# shuffle(arr) -> shuffled arr
#
# Shuffle the elements in the array. 

sub shuffle {
  my (@arr) = @_;

  my @shufflix;
  my @shuffler;

  for(my $i = 0; $i <= $#arr; $i++) {
    $shufflix[$i] = $i;
    $shuffler[$i] = rand();
  }

  @shufflix = sort { $shuffler[$a] <=> $shuffler[$b] } @shufflix;

  my @shuffled;

  for(my $i = 0; $i <= $#arr; $i++) {
    $shuffled[$i] = $arr[$shufflix[$i]];
  }

  return @shuffled;
}

# Old method, which relies on the array having no two equal items
#{
#  my @shuffler;
#  my %indexes;
#  for(my $i = 0; $i <= $#arr; $i++) {
#    $indexes{$arr[$i]} = $i;
#    
#    $shuffler[$i] = rand();
#  }
#
#  my @shuffled = sort { $shuffler[$indexes{$a}]
#			  <=> $shuffler[$indexes{$b}] } @arr;
#  return @shuffled;
#}

# combinations(n, r) -> c
#
# Return n! / r!(n - r)!
#
# According to this webpage: http://blog.plover.com/math/choose.html
# This is best done observing that
#
# C(n + 1, r + 1) = ((n + 1) / (r + 1)) * C(n, r)
#
# With C(n, 0) = 1, and c(0, r) = 0

sub combinations {
  my ($n, $r) = 0;

  return 0 if($r > $n);

  my $c = 1;

  $r = $n - $r if($r > $n / 2);

  for(my $i = $r; $i >= 1; $i--, $n--) {
    $c *= $n / $i;	     
				# The website recommends multiplying by n
				# then dividing by i to avoid rounding errors
				# I don't really care here...
  }

  return $c;
}

# mv(from, to)
#
# Moves one directory to another

sub mv {
  my ($from, $to) = @_;

  mkdir($to) or die "Cannot create directory $to: $!\n";

  opendir(DIR, "$from") or die "Cannot read directory $from: $!\n";
  foreach my $file (readdir(DIR)) {
    next if($file eq '.' || $file eq '..');
    link("$from/$file", "$to/$file")
      or die "Cannot link $from/$file to $to/$file: $!\n";
    unlink("$from/$file") or die "Cannot unlink $from/$file: $!\n";
  }
  closedir(DIR);
  
  rmdir($from) or die "Cannot remove directory $from: $!\n";

  &log("Moved $from to $to");
}

# cp(from, to)
#
# Copies one directory to another

sub cp {
  my ($from, $to) = @_;

  mkdir($to) or die "Cannot create directory $to: $!\n";

  opendir(DIR, "$from") or die "Cannot read directory $from: $!\n";
  foreach my $file (readdir(DIR)) {
    next if($file eq '.' || $file eq '..');
    open(FROM, "<$from/$file") or die "Cannot read file $from/$file: $!\n";
    open(TO, ">$to/$file") or die "Cannot create file $to/$file: $!\n";
    print TO <FROM>;
    close(TO);
    close(FROM);
  }
  closedir(DIR);

  &log("Copied $from to $to");
}

# rm(dir)
#
# Removes a directory

sub rm {
  my ($dir) = @_;

  opendir(DIR, "$dir") or die "Cannot read directory $dir: $!\n";
  foreach my $file (readdir(DIR)) {
    next if($file eq '.' || $file eq '..');
    unlink("$dir/$file") or die "Cannot unlink $dir/$file: $!\n";
  }
  closedir(DIR);

  rmdir($dir) or die "Cannot remove directory $dir: $!\n";

  &log("Removed $dir");
}

# log(data)
#
# Logs information

sub log {
  my @data = @_;

  my ($sec, $min, $hour, $mday, $mon, $year) = localtime;

  open(LOG, ">>$log") or die "Cannot append to log file $log: $!\n";
  print LOG "SPOMM-MGAv3 ($$) ", $year + 1900,
  sprintf("%02d%02d", $mon + 1, $mday), "T",
  sprintf("%02d%02d%02d", $hour, $min, $sec), ": ", join(" ", @data), "\n";
  close(LOG);
}
