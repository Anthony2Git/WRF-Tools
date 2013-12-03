#!/bin/bash
# script to synchronize datasets with SciNet

LOC=/data/ # local datasets root
REM=/reserved1/p/peltier/aerler/Datasets/ # datasets root on SciNet
DATASETS='GPCC NARR CFSR CRU PRISM' # list of datasets/folders
# DATASETS='PRISM' # for tests

echo
hostname
date
echo 
echo "   >>>   Synchronizing Local Datasets with SciNet   <<<   " 
echo
echo "      Local:  ${LOC}"
echo "      Remote: ${REM}"
echo

# loop over datasets
ERR=0
echo
for D in ${DATASETS}
  do
    echo "${D}"
    E="${LOC}/${D}" # no trailing slash!
    # use rsync for the transfer; verbose, archive, update, gzip
    time rsync -vauz -e 'ssh -i /data/.rsync/rsync -o BatchMode=yes'  "${E}" "aerler@login.scinet.utoronto.ca:${REM}"
    ERR=$(( $ERR + $? )) # capture exit code
    # N.B.: with connection sharing, repeating connection attempts is not really necessary
    echo    
done # for regex sets

# report
echo
if [ $ERR == 0 ]
  then
    echo "   <<<   All Transfers Completed Successfully!   >>>   "
  else
    echo "   ###   Transfers Completed - there were ${ERR} Errors!   ###   "
fi
echo

# exit
exit $ERR
