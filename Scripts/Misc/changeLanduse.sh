#!/bin/bash
# short script to change landuse parameters in WRF geogrid output
# Andre R. Erler, 09/02/2015

set -e # exit at first sign of trouble

for GEO in geo_em.d0?.nc
  do
    # convert to classic NetCDF4 format (otherise there are problems)
    ncks -7 "$GEO" tmp.nc
    # change landuse
    echo 'yes' | ./bin/read_wrf_nc -EditData LU_INDEX tmp.nc
    # save new file
    mv "$GEO" "${GEO%.nc}.orig.nc"
    mv tmp.nc "$GEO"
done
  