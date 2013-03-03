#!/bin/bash
# script to resubmit next job after current job completed
# Andre R. Erler, 28/02/2013

## launch WRF for next step (if $NEXTSTEP is not empty)
if [[ -n "${NEXTSTEP}" ]]
  then

    # read date string for restart file
    RSTDATE=$(sed -n "/${NEXTSTEP}/ s/${NEXTSTEP}\s.\(.*\).\s.*$/\1/p" stepfile)
    NEXTDIR="${INIDIR}/${NEXTSTEP}" # next $WORKDIR
    cd "${NEXTDIR}"
    # link restart files
    echo
    echo "Linking restart files to next working directory:"
    echo "${NEXTDIR}"
    for RESTART in "${RSTDIR}"/wrfrst_d??_"${RSTDATE}"; do
	ln -sf "${RESTART}"; done

    # check for WRF input files (in next working directory)
    if [[ "${WAITFORWPS}" == 'WAIT' ]] && [[ ! -e "${INIDIR}/${NEXTSTEP}/${DEPENDENCY}" ]]
      then
	echo
	echo "   ***   Waiting for WPS to complete...   ***"
	echo
	while [[ ! -e "${INIDIR}/${NEXTSTEP}/${DEPENDENCY}" ]]; do
		sleep 5 # need faster turnover to submit next step
	done
    fi # $WAITFORWPS

    # submit next job (start next cycle)
    cd "${INIDIR}"
    echo
    echo "   ***   Launching WRF for next step: ${NEXTSTEP}   ***   "
    echo
    # execute submission command (set in setup-script; machine-specific)
    echo "Command: " ${RESUBJOB} # print command
    echo "Variables: INIDIR=${INIDIR}, NEXTSTEP=${NEXTSTEP}, SCRIPTNAME=${SCRIPTNAME}"
    eval "${RESUBJOB}" # execute command

fi # $NEXTSTEP
