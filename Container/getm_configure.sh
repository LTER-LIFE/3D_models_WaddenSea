#!/bin/sh

#export ifort=$FORTRAN_COMPILER
#export CMAKE_Fortran_Compiler=$ifort

echo "COMPILATION_MODE: " $COMPILATION_MODE

# if not set use the suggested source code installation directories
GETM_BASE=${GETM_BASE:=$HOME/home/getm-git/}
GOTM_BASE=${GOTM_BASE:=$HOME/home/gotm-git/}
FABM_BASE=${FABM_BASE:=$HOME/home/fabm-git/fabm/}

# default Fortran compiler is gfortran - overide by setting compiler like:
export compiler=gfortran
#compiler=${compiler:=gfortran}
#compiler=$FORTRAN_COMPILER

# horizontal coordinate system to use - default Cartesian
# other options are Spherical or Curvilinear
# to set use e.g.:
export coordinate=Spherical
#coordinate=${coordinate:=Cartesian}

# configurable installation prefix
# override by e.g.:
# export install_prefix=/tmp
# note that $compiler will be appended
install_prefix=${install_prefix:=~/local/getm}

# NetCDF
# nf-config must be in the path and correpsond to the value of compiler
# try:
nf-config --all

# ready to configure
mkdir -p $compiler
cd $compiler
cmake $GETM_BASE/src \
      -DGETM_EMBED_VERSION=on \
      -DGOTM_BASE=$GOTM_BASE \
      -DGETM_USE_FABM=off \
      -DFABM_BASE=$FABM_BASE/ \
      -DCMAKE_Fortran_COMPILER=$compiler \
      -DGETM_USE_PARALLEL=on \
      -DGETM_USE_STATIC=ON \
      -DGETM_COORDINATE_TYPE=$coordinate \
      -DGETM_FLAGS="-D_DELAY_SLOW_IP_ -D_SLR_V26_ -D_NEW_DAF_" \
      -DGETM_USE_BFM=ON\
      -DCMAKE_INSTALL_PREFIX=$install_prefix/$compiler \
#      -DCMAKE_BUILD_TYPE=Debug
#      -DCMAKE_BUILD_TYPE=Production
#      -DGETM_FLAGS="-DMUDFLAT" \
#      -DCMAKE_Fortran_FLAGS="-g -C -check -traceback -check noarg_temp_created"
#      -DCMAKE_Fortran_FLAGS="-pr"
#      -DGETM_FLAGS="-D_SLR_V26_" \
#      -DCMAKE_BUILD_TYPE=Debug

#GETM_FLAGS:
#-D_SLR_V26_:       old friction behaviour
#-D_DELAY_SLOW_IP_: Internal pressure: improved stability deep water
#-D_NEW_DAF_:       new flooding and drying
cd ..
