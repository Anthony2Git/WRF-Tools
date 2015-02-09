# ============================================================================
# Name        : Makefile
# Author      : Andre R. Erler
# Version     : 0.2
# Copyright   : GPL v3
# Description : Makefile for Fortran Tools
# ============================================================================

.PHONY: all clean

## Select Build System here: Intel, GFortran, GPC
#SYSTEM = GFortran
# default build
ifndef SYSTEM
SYSTEM = Intel
endif
# debugging flags
#MODE = Debug

## Load Build Environment
# Standard Intel
ifeq ($(SYSTEM), Intel)
include config/Intel # Intel Compiler
endif
# Standard GFortran
ifeq ($(SYSTEM), GFortran)
include config/GFortran # GFortran Compiler
endif
# GPC, SciNet
ifeq ($(SYSTEM), GPC)
include config/GPC # Intel Compiler
endif
# P7, SciNet
ifeq ($(SYSTEM), P7)
include config/P7 # IBM Linux Compiler
endif

## Assemble Flags
ifeq ($(MODE), Debug)
FCFLAGS = $(DBGFLAGS) -pg -DDEBUG -DDIAG
else
FCFLAGS = $(OPTFLAGS) -DDIAG
endif

# this gets build before other scripts are executed
all: unccsm read_wrf_nc

## build unccsm.exe program to convert CCSM netcdf output to WRF intermediate files
unccsm: unccsm.exe

unccsm.exe: bin/nc2im.o
	$(FC) $(FCFLAGS) -o bin/$@ $^ $(NC_LIB)
	mv bin/unccsm.exe bin/$(SYSTEM)/

bin/nc2im.o: Fortran/nc2im.f90
	$(FC) $(FCFLAGS) $(NC_INC) -c $^
	mv nc2im.o bin/

## build convert_spectra to convert spherical harmonic coefficients from ECMWF
# grib files to total wavenumber spectra and save as netcdf
spectra: convert_spectra

convert_spectra: bin/gribSpectra.o
	$(FC) $(FCFLAGS) -o bin/$@ $^ $(GRIBLIBS) $(NCLIBS)

bin/gribSpectra.o: Fortran/gribSpectra.f90
	$(FC) $(FCFLAGS) $(INCLUDE) -c $^
	mv gribSpectra.o bin/

## build read_wrf_nc to change landuse parameters in geogrid
read_wrf_nc: read_wrf_nc

read_wrf_nc: bin/read_wrf_nc.o
	$(FC) $(FCFLAGS) -o bin/$@ $^ $(NC_LIB)
	mv bin/read_wrf_nc bin/$(SYSTEM)/

bin/read_wrf_nc.o: Fortran/read_wrf_nc.f90
	$(FC) $(FCFLAGS) $(NC_INC) -c $^
	mv read_wrf_nc.o bin/


clean:
	rm -f bin/*.exe bin/*.mod bin/*.o bin/*.so bin/*.a

### F2Py Flags (for reference)
#F2PYCC = intelem
#F2PYFC = intelem
#F2PYFLAGS = -openmp # -parallel -par-threshold50 -par-report3
#F2PYOPT = -O3 -xHost -no-prec-div -static
#PYTHON_MODULE_LOCATION = # relative path
