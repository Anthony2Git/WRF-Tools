#!/bin/bash
# script to set up a cycling WPS/WRF run: reads first entry in stepfile and 
# starts/submits first WPS and WRF runs, the latter dependent on the former
# created 28/06/2012 by Andre R. Erler, GPL v3

# settings
set -e # abort if anything goes wrong
NOGEO=$1 # option to run without geogrid
STEPFILE='stepfile' # file in $INIDIR
INIDIR="${PWD}" # current directory
METDATA="${INIDIR}/metgrid/"
WRFOUT="${INIDIR}/wrfout/"
WPSSCRIPT="run_cycling_WPS.sh"
WRFSCRIPT="run_cycling_WRF.sh"
STATICTGZ='static.tgz' # file for static data backup

# launch feedback
echo
echo "   ***   Starting Cycle  ***   "
echo
# echo "   Stepfile: ${STEPFILE}"
echo "   Root Dir: ${INIDIR}"
echo

# clear some folders
cd "${INIDIR}"
echo "   Clearing Output Folders:"
echo "${METDATA}"
echo "${WRFOUT}"
rm -rf "${METDATA}" "${WRFOUT}"
mkdir -p "${WRFOUT}"
echo

# run geogrid
# clear files
cd "${INIDIR}"
if [[ "${NOGEO}" == 'NOGEO'* ]]; then
  echo "   Not running geogrid.exe"
else
  rm -f geo_em.d??.nc geogrid.log*
  # run with parallel processes
  echo "   Running geogrid.exe"
  mpirun -n $OMP_NUM_THREADS ./geogrid.exe
  # N.B.: $OMP_NUM_THREADS is used as a proxy for # cores
fi

# read first entry in stepfile
export STEPFILE
NEXTSTEP=$(python cycling.py)
export NEXTSTEP
echo
echo "   First Step: ${NEXTSTEP}"
echo

# prepare first working directory
# set restart to False for first step
sed -i '/restart\s/ s/restart\s*=\s*\.true\..*$/restart = .false.,/' \
 "${INIDIR}/${NEXTSTEP}/namelist.input"  
# and make sure the rest is on restart
sed -i '/restart\s/ s/restart\s*=\s*\.false\..*$/restart = .true.,/' \
 "${INIDIR}/namelist.input"
echo "  Setting restart option and interval in namelist."
# echo

# create backup of static files
cd "${INIDIR}"
rm -rf 'static-tmp/' 
mkdir -p 'static-tmp'
echo $( cp -P * 'static-tmp/' &> /dev/null ) # trap this error and hide output
cp -rL 'meta/' 'tables/' 'static-tmp/'
tar czf "${STATICTGZ}" 'static-tmp/'
rm -r 'static-tmp/'
mv "${STATICTGZ}" "${WRFOUT}"
echo "  Saved backup file for static data:"
echo "${WRFOUT}/${STATICTGZ}"
echo

# launch first WPS instance
./${WPSSCRIPT}
wait

# launch first WRF instance
./${WRFSCRIPT}
wait
