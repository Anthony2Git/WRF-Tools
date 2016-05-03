#!/bin/bash
# script to delay a WRF run start until WPS is finished (for P7)
# created 15/08/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
export NEXTSTEP="$1" # step name/folder as first argument
export NOWPS="$2" # to run or not to run WPS
export INIDIR=${INIDIR:-"${PWD}"} # current directory
export SCRIPTDIR="${INIDIR}/scripts/"
export WPSSCRIPT="run_cycling_WPS.pbs"
export WPSWCT=''
export WRFSCRIPT="run_cycling_WRF.ll"
export WRFWCT=''

# source launch commands
source "${SCRIPTDIR}/setup_WRF.sh"

# launch feedback
echo
echo "   Next Step: ${NEXTSTEP}"
# echo "   Root Dir: ${INIDIR}"
echo

# submit first independent WPS job to GPC (not TCS!)
echo
if [[ "$NOWPS" != 'NOWPS' ]]
  then
    echo "   Submitting first WPS job to queue:"
    echo "Command: "${SUBMITWPS} # print command
    echo "Variables: INIDIR=${INIDIR}, NEXTSTEP=${NEXTSTEP}, DEPENDENCY=${WPSSCRIPT}"
    eval "${SUBMITWPS}" # using variables: $INIDIR, $DEPENDENCY, $NEXTSTEP
else
    echo "   WARNING: not running WPS! (make sure WPS was started manually)"
fi
echo

# wait until WPS job is completed: check presence of WPS script as signal of completion
echo
echo "   Waiting for WPS job on GPC to complete..."
while [[ ! -e "${INIDIR}/${NEXTSTEP}/${WPSSCRIPT}" ]]
  do
    sleep 30
done
echo "   ... WPS completed."
echo

# submit first WRF instance on TCS
echo
echo "   Submitting first WRF job to queue:"
export NEXTSTEP # this is how env vars are passed to LL
export NOWPS
echo "Command: " ${RESUBJOB} # print command
echo "Variables: INIDIR=${INIDIR}, NEXTSTEP=${NEXTSTEP}, SCRIPTNAME=${WRFSCRIPT}"
eval "${RESUBJOB}" # execute command
echo
