#!/bin/sh
#$ -cwd
#$ -t 1-20803
# In the CSV files there are 1349568 lines (ABC4) or 1037952 (ABC6)
# I'm not sure from where all these data were obtained, but in the
# directories cedss-abc4 and cedss-abc6 as at 16 April 2019, there
# are 4414 and 16389 tar.bz2 files respectively. It is these that
# will be reanalysed.

TOPDIR="/mnt/storage/gary"
SCRIPTDIR="abc4abm/CEDSS-ABC6-scripts"
SCRIPT="analyseCEDSS.pl"
VALFILE="cedss3.3-20190403-Urban-energy-match-totals.csv"
ERRSCRIPT="energyerr.pl"

# Default to the ABC4 runs
LS="$TOPDIR/$SCRIPTDIR/cedss-abc4.ls"
LL4=`wc -l $LS | awk '{print $1}'` # Number of (ABC4) tar files with results in
RUN=$SGE_TASK_ID

if [[ "$SGE_TASK_ID" -gt "$LL4" ]]
then
    # Run out of ABC4 runs, so switch to ABC6
    
    RUN=$(expr $SGE_TASK_ID - $LL4)
    LS="$TOPDIR/$SCRIPTDIR/cedss-abc6.ls"
fi

# Pick a tar file from the list
FULTAR=`head -n $RUN $LS | tail -n 1`
FULDIR=`echo $FULTAR | sed -e 's/.tar.bz2$//'`

ABCDIR=`dirname $FULDIR`
RUNDIR=`basename $FULDIR`

if [[ ! -e "$TOPDIR/$ABCDIR/$VALFILE" ]]
then
    cp $TOPDIR/$SCRIPTDIR/$VALFILE $TOPDIR/$ABCDIR
    cp $TOPDIR/$SCRIPTDIR/$ERRSCRIPT $TOPDIR/$ABCDIR
fi


cd $TOPDIR/$ABCDIR

$TOPDIR/$SCRIPTDIR/$SCRIPT -zip $RUNDIR

exit 0
