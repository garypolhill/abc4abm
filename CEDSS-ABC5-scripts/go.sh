#!/bin/sh

SPLIT=${1-splitU}
MAX_PROC=32
PROC=0
COUNT=0
i=0
HOST=`hostname | awk -F. '{print $1}'`
RESULTS="cedss-$SPLIT-$HOST.csv"

echo "Running in split mode $SPLIT"

# every other sample is a 'normal' (not null) sample
# null samples cycle through nulling all parameters, and nulling one at a time
SAMPLES=( \
  "-mode $SPLIT"  "-mode $SPLIT -null" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull bioboost" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull credit" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull habitadjust" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull maxlinks -pnull visits -pnull newsubcatapp -pnull newsubcatstep" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull hedonism1 -pnull hedonism2" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull egoism1 -pnull egoism2" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull biospherism1 -pnull biospherism2" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull frame1 -pnull frame2" \
  "-mode $SPLIT"  "-mode $SPLIT -pnull planning1 -pnull planning2" )
n=${#SAMPLES[@]}

touch 'continue'

while test -e 'continue'
do
  if test $PROC -ge $MAX_PROC
  then
    wait
    PROC=0
  fi

  if test $i -ge $n
  then
    i=0
  fi

  COUNT=`expr $COUNT + 1`
  RUNDIR="${HOST}-`printf \"%04d\" $COUNT`"

  ./sampleCEDSS.pl -rundir $RUNDIR -zip ${SAMPLES[$i]} &

  PROC=`expr $PROC + 1`
  i=`expr $i + 1`
  
  sleep 1
done

wait

echo "Initiated $COUNT runs from $HOST"

for file in $HOST-*-results.csv
do
  if test -e $RESULTS
  then
    tail -n +2 $file >> $RESULTS
  else
    cp $file $RESULTS
  fi
done
