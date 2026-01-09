# getm.sh

# Uncomment the following line if you don't like systemctl's auto-paging feature:
# export SYSTEMD_PAGER=

# User specific aliases and functions

# load modules

# testing package to run getm-iow
module purge
module load EasyBuild/3.9.4 # this softwave is used for managing packages interdependencies on HPC
#module load CMake/3.15.4-GCCcore-6.4.0
module load CMake/3.9.1-GCCcore-6.4.0
module load netCDF-Fortran/4.4.4-foss-2018a
module load netCDF/4.6.0-foss-2018a
# comment next line out for running GETM: screws up HDF5 library...
# module load netcdf/4.6.1 #for nco tools

# moodule paths
export PATH=/opt/laplace/NCO/bin:$PATH

#Definitions for GETM/GOTM compiler
export FORTRAN_COMPILER=GFORTRAN

#export FC=gcc
unset FC
unset LDFLAGS

export MPI=OPENMPI


export NETCDF_VERSION="NETCDF4"
#export NETCDFINC=/opt/ohpc/pub/libs/gnu7/openmpi3/netcdf-fortran/4.4.4/include
export NETCDFINC=$HOME/.local/easybuild/software/netCDF-Fortran/4.4.4-foss-2018a/include
export NETCDFLIBNAME=netcdf.inc
export NETCDFLIBDIR=$HOME/.local/easybuild/software/netCDF-Fortran/4.4.4-foss-2018a/lib

export COMPILATION_MODE="production"
export GETM_PARALLEL=true

export GOTMDIR=$HOME/home/gotm-git/
export FABMDIR=$HOME/home/fabm-git/fabm/
export BFMDIR=$HOME/home/BFM_SOURCES/bfm_2016
export GETMDIR=$HOME/home/getm-git/

export GOTM_BUILD_DIR=$HOME/home/build/gotm