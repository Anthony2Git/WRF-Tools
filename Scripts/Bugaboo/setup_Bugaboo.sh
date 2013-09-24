#!/bin/bash
# source script to load Bugaboo-specific settings for pyWPS, WPS, and WRF
# created 11/06/2013 by Andre R. Erler, GPL v3

# load modules
echo
module purge
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
    module load python # don't load specific version, or it crashes with next update     
    # N.B.: NCL is only necessary to process CESM output
fi
module list
echo

# RAM-disk settings: infer from queue
if [[ ${RUNPYWPS} == 1 ]] && [[ ${RUNREAL} == 1 ]]
  then
    export RAMIN=${RAMIN:-1}
    export RAMOUT=${RAMOUT:-0}
  else
    export RAMIN=${RAMIN:-0}
    export RAMOUT=${RAMOUT:-0}
fi # if WPS
echo
echo "Running on ${PBS_QUEUE} queue; RAMIN=${RAMIN} and RAMOUT=${RAMOUT}"
echo

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/${USER}/"
# check if the RAM=disk is actually there
if [[ ${RAMIN}==1 ]] || [[ ${RAMOUT}==1 ]]; then
    # create RAM-disk directory
    mkdir -p "${RAMDISK}"
    # report problems
    if [[ $? != 0 ]]; then
      echo
      echo "   >>>   WARNING: RAM-disk at RAMDISK=${RAMDISK} - Error creating folder!   <<<"
      echo
    fi # no RAMDISK
fi # RAMIN/OUT

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s hard

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# set up hybrid envionment: OpenMP and MPI (Intel)
export NODES=${NODES:-${PBS_NUM_NODES}} # set in PBS section
export TASKS=${TASKS:-12} # number of MPI task per node (Hpyerthreading!)
export THREADS=${THREADS:-1} # number of OpenMP threads
# OpenMPI job launch command
export HYBRIDRUN=${HYBRIDRUN:-'mpiexec -n $((NODES*TASKS))'} # evaluated by execWRF and execWPS

# WPS/preprocessing submission command (for next step)
export SUBMITWPS=${SUBMITWPS:-'cd ${INIDIR} && qsub ./${WPSSCRIPT} -v NEXTSTEP=${NEXTSTEP}'} # use Python script to estimate queue time and choose queue
export WAITFORWPS=${WAITFORWPS:-'NO'} # stay on compute node until WPS for next step finished, in order to submit next WRF job

# archive submission command (for last step)
export SUBMITAR=${SUBMITAR:-'echo "Automatic archiving is currently not available."'} # evaluated by launchPostP
# N.B.: requires $ARTAG to be set in the launch script

# job submission command (for next step)
export RESUBJOB=${RESUBJOB-'cd ${INIDIR} && qsub ./${WRFSCRIPT} -v NOWPS=${NOWPS},NEXTSTEP=${NEXTSTEP}'} # evaluated by resubJob
