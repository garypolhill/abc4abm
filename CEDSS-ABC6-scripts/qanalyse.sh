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
LL4=`wc -l $LS`			# Number of (ABC4) tar files with results in
RUN=$SGE_TASK_ID

if [[ $RUN -gt $LL4 ]]
then
    # Run out of ABC4 runs, so switch to ABC6
    
    RUN=$(expr $SGE_TASK_ID - $LL4)
    LS="$TOPDIR/$SCRIPTDIR/cedss-abc6.ls"
fi

# Pick a tar file from the list
FULTAR=`head -n $SGE_TASK_ID $LS | tail -n 1`
FULDIR=`echo $FULTAR | sed -e 's/.tar.bz2$//'`

TAR=`basename $FULTAR`
ABCDIR=`dirname $FULDIR`
RUNDIR=`basename $FULDIR`

if [[ ! -e "$TOPDIR/$ABCDIR/$VALFILE" ]]
then
    cp $TOPDIR/$SCRIPTDIR/$VALFIE $TOPDIR/$ABCDIR
    cp $TOPDIR/$SCRIPTDIR/$ERRSCRIPT $TOPDIR/$ABCDIR
fi


cd $TOPDIR/$ABCDIR

tar jxf $TAR			# Extract the results in the ABC dir
				# (the script will wrap them back up
				# again)

$TOPDIR/$SCRIPTDIR/$SCRIPT -zip $RUNDIR

exit 0
