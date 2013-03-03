#!/bin/bash
# source script to load GPC-specific settings for pyWPS, WPS, and WRF
# created 06/07/2012 by Andre R. Erler, GPL v3

# launch feedback etc.
echo
hostname
uname
echo
echo "   ***   ${PBS_JOBNAME}   ***   "
echo

# load modules
module purge
module load intel/12.1.3 intelmpi/4.0.3.008 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel
#module load intel/12.1.3 intelmpi/4.0.3.008 hdf5/187-v18-serial-intel netcdf/4.1.3_hdf5_serial-intel
# pyWPS.py specific modules
if [[ ${RUNPYWPS} == 1 ]]; then
	module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
	#module load gcc/4.6.1 centos5-compat/lib64 ncl/6.0.0 python/2.7.2
fi
module list
echo

# unlimit stack size (unfortunately necessary with WRF to prevent segmentation faults)
ulimit -s unlimited

# cp-flag to prevent overwriting existing content
export NOCLOBBER='-n'

# RAM disk folder (cleared and recreated if needed)
export RAMDISK="/dev/shm/aerler/"

# set up hybrid envionment: OpenMP and MPI (Intel)
#export KMP_AFFINITY=verbose,granularity=thread,compact
#export I_MPI_PIN_DOMAIN=omp
export I_MPI_DEBUG=1 # less output (currently no problems)
# Intel hybrid (mpi/openmp) job launch command
export HYBRIDRUN='mpirun -ppn ${TASKS} -np $((NODES*TASKS))' # evaluated by execWRF and execWPS

# job submission command (for next step)
export RESUBJOB='ssh gpc01 "cd ${INIDIR}; qsub ./${SCRIPTNAME} -v NEXTSTEP=${NEXTSTEP}"' # evaluated by resubJob
