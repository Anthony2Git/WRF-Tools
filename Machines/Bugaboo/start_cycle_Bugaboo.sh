#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3
# revised 02/03/2013 by Andre R. Erler, GPL v3

set -e # abort if anything goes wrong
# settings
export STEPFILE=${STEPFILE:-'stepfile'} # file in $INIDIR
export INIDIR=${INIDIR:-"${PWD}"} # current directory
export SCRIPTDIR=${SCRIPTDIR:-"./scripts"} # location of the setup-script
export BINDIR=${BINDIR:-"./bin/"} # location of geogrid.exe
export METDATA=${METDATA:-''} # don't save metgrid output
export WRFOUT=${WRFOUT:-"${INIDIR}/wrfout/"} # WRF output folder
export WPSSCRIPT=${WPSSCRIPT:-'run_cycling_WPS.pbs'} # WPS run-scripts
export WRFSCRIPT=${WRFSCRIPT:-'run_cycling_WRF.pbs'} # WRF run-scripts
export STATICTGZ=${STATICTGZ:-'static.tgz'} # file for static data backup
# geogrid command (executed during machine-independent setup)
export GEOGRID=${GEOGRID:-"mpirun -n 4 ${BINDIR}/geogrid.exe > /dev/null"} # hide stdout

# translate arguments
export MODE="${1}" # NOGEO*, RESTART, START
export LASTSTEP="${2}" # previous step in stepfile (leave blank if this is the first step)


## start setup
cd "${INIDIR}"

# read first entry in stepfile
NEXTSTEP=$( python "${SCRIPTDIR}/cycling.py" "${LASTSTEP}" )
export NEXTSTEP

# run (machine-independent) setup:
eval "${SCRIPTDIR}/setup_cycle.sh" # requires geogrid command


## launch jobs

# submit first WPS instance
qsub ./${WPSSCRIPT} -v NEXTSTEP="${NEXTSTEP}"

# submit first WRF instance
qsub ./${WRFSCRIPT} -v NEXTSTEP="${NEXTSTEP}" -W depend:afterok:cycling_WPS
# N.B. the name of the dependency has to be changed by the setup script!

# exit with 0 exit code: if anything went wrong we would already have aborted
exit 0
