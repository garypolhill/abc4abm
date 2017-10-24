#!/bin/sh
MAX_PROC=16
PROC=0
COUNT=0
i=0
HOST=`hostname | awk -F. '{print $1}'`
RESULTS="cedss-abc-$HOST.csv"
declare -a FILES

for file in ${HOST}*.err
do
  if test $PROC -ge $MAX_PROC
  then
    wait
    PROC=0
  fi

  RUNDIR=`echo $file | sed -e 's/\.err$//'`

  echo "Trying ${RUNDIR}"
  if test -e "${RUNDIR}-8"
  then
    ./analyseCEDSS.pl -zip $RUNDIR &

    echo "Staring ${RUNDIR}"
    FILES[$i]="${RUNDIR}-results.csv"

    PROC=`expr $PROC + 1`
    i=`expr $i + 1`

    sleep 1
  fi
done

wait

for file in ${FILES[@]}
do
  if test -e $RESULTS
  then
    tail -n +2 $file >> $RESULTS
  else
    cp $file $RESULTS
  fi
done

