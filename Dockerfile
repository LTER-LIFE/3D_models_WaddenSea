# --------------------------
# Base image: Ubuntu 18.04 (HPC-like)
# --------------------------
FROM ubuntu:18.04

LABEL maintainer="Qing Zhan"
LABEL description="HPC-like environment for GOTM/FABM with GCC 6.4"

# --------------------------
# Install system dependencies
# --------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    wget \
    curl \
    git \
    tar \
    gzip \
    bzip2 \
    libhdf5-dev \
    ca-certificates \
    python3 \
    python3-venv \
    python3-dev \
    python3-pip \
    zlib1g-dev \
    nano \
    && rm -rf /var/lib/apt/lists/*


# --------------------------
# Install GCC 6.4 / gfortran-6
# --------------------------
RUN apt-get update && apt-get install -y \
    gcc-6 g++-6 gfortran-6 \
    && rm -rf /var/lib/apt/lists/*

# Install m4 (required by netCDF build) and other dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    m4 \
    && rm -rf /var/lib/apt/lists/*

# Set GCC 6.4 as default
RUN update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-6 100 && \
    update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-6 100 && \
    update-alternatives --install /usr/bin/gfortran gfortran /usr/bin/gfortran-6 100

# --------------------------
# Install CMake 3.9.1
# --------------------------
COPY cmake-3.9.1.tar.gz /tmp/
RUN cd /tmp && \
    tar -xzf cmake-3.9.1.tar.gz && \
    cd cmake-3.9.1 && \
    ./bootstrap --prefix=/usr/local && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/cmake-3.9.1*

# --------------------------
# Install netCDF-C 4.6.0
# --------------------------
COPY netcdf-c-4.6.0.tar.gz /tmp/
RUN apt-get update && apt-get install -y --no-install-recommends libhdf5-dev && rm -rf /var/lib/apt/lists/* && \
    cd /tmp && \
    tar -xzf netcdf-c-4.6.0.tar.gz && \
    cd netcdf-c-4.6.0 && \
    CPPFLAGS="-I/usr/include/hdf5/serial" LDFLAGS="-L/usr/lib/x86_64-linux-gnu/hdf5/serial" \
    ./configure --prefix=/opt/netcdf-c-4.6.0 --disable-dap && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/netcdf-c-4.6.0*

# --------------------------
# Install netCDF-Fortran 4.4.4
# --------------------------
# NetCDF-C first
# Then NetCDF-Fortran, linking it to the NetCDF-C install
COPY netcdf-fortran-4.4.4.tar.gz /tmp/
RUN cd /tmp && \
    tar -xzf netcdf-fortran-4.4.4.tar.gz && \
    cd netcdf-fortran-4.4.4 && \
    CPPFLAGS="-I/opt/netcdf-c-4.6.0/include" LDFLAGS="-L/opt/netcdf-c-4.6.0/lib" \
    ./configure --prefix=/opt/netcdf-fortran-4.4.4 --disable-shared && \
    make -j$(nproc) && make install && \
    cd / && rm -rf /tmp/netcdf-fortran-4.4.4*

# --------------------------
# Build-time arguments for Git credentials
# --------------------------
ARG GIT_USERNAME
ARG GIT_TOKEN

# Expose as environment variables for RUN commands
ENV GIT_USERNAME=${GIT_USERNAME}
ENV GIT_TOKEN=${GIT_TOKEN}

# --------------------------
# Environment variables (HPC-like)
# --------------------------
ENV PATH="/opt/laplace/NCO/bin:/opt/netcdf-c-4.6.0/bin:/opt/netcdf-fortran-4.4.4/bin:${PATH}"
ENV FORTRAN_COMPILER=GFORTRAN
ENV NETCDF=/opt/netcdf-fortran-4.4.4
ENV NETCDF_ROOT=/opt/netcdf-fortran-4.4.4
ENV NETCDF_LIBDIR=/opt/netcdf-fortran-4.4.4/lib
ENV NETCDF_INCDIR=/opt/netcdf-fortran-4.4.4/include
ENV LD_LIBRARY_PATH=/opt/netcdf-fortran-4.4.4/lib:/opt/netcdf-c-4.6.0/lib:$LD_LIBRARY_PATH
ENV COMPILATION_MODE=production
ENV GETM_PARALLEL=true

ENV ImageHome=/opt
ENV GOTMDIR=/opt/home/GOTM_SOURCES/gotm_coupled_bfm_2016/
ENV FABMDIR=/opt/home/fabm-git/fabm
ENV BFMDIR=/opt/home/BFM_SOURCES/bfm_2016
ENV GETMDIR=/opt/home/getm-git
ENV GOTM_BUILD_DIR=/opt/build/gotm


# --------------------------
# Clone repositories during build
# --------------------------
RUN mkdir -p $ImageHome/home/BFM_SOURCES \
             $ImageHome/home/GOTM_SOURCES \
             $ImageHome/home/GETM_SOURCES \
             $ImageHome/home/fabm-git && \
    cd $ImageHome/home/BFM_SOURCES && \
    git clone "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/jvdmolen/bfm_2016.git" && \
    cd bfm_2016 && git checkout -b bfm2016_production_20250827 remotes/origin/bfm2016_production_20250827 && \
    cd $ImageHome/home/GOTM_SOURCES && \
    git clone "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/jvdmolen/gotm_coupled_bfm_2016.git" && \
    cd gotm_coupled_bfm_2016 && \
    git checkout -b master_20210107_couplingGETM_bfm2016_20241126 remotes/origin/master_20210107_couplingGETM_bfm2016_20241126 && \
    git submodule update --init --recursive && \
    cd $ImageHome/home/GETM_SOURCES && \
    git clone "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/jvdmolen/getm_coupled_bfm_2016.git" && \
    cd getm_coupled_bfm_2016 && \
    git checkout -b iow_20200609_bfm2016_20250116 remotes/origin/iow_20200609_bfm2016_20250116 && \
    cd $ImageHome/home/fabm-git && \
    git clone "https://${GIT_USERNAME}:${GIT_TOKEN}@github.com/fabm-model/fabm.git" && \
    cd fabm && git checkout -b master_20200610 e1f1f08e42d84f8324f5114924b67ad567719334


#######################################################################
#######################################################################
# Patch broken CMake dependencies in GOTM-BFM coupling
RUN sed -i \
    -e 's/add_dependencies(global_mod util)/# add_dependencies(global_mod util)/' \
    -e 's/add_dependencies(gotm bio)/# add_dependencies(gotm bio)/' \
    $ImageHome/home/GOTM_SOURCES/gotm_coupled_bfm_2016/src/CMakeLists.txt


## Because of the commands above, you will get stukt by 
# make install # to make a GOTM executable, because you changed the CMake dependencies

#####
# Error logs:
44%] Building Fortran object gotmlib/CMakeFiles/gotm.dir/gotm.F90.o
/opt/home/GOTM_SOURCES/gotm_coupled_bfm_2016/src/gotm/gotm.F90:100:7:

    use bio,only:init_var_bio,init_bio,do_bio,end_bio,bio_calc, &
       1
Fatal Error: Can't open module file 'bio.mod' for reading at (1): No such file or directory
compilation terminated.
gotmlib/CMakeFiles/gotm.dir/build.make:62: recipe for target 'gotmlib/CMakeFiles/gotm.dir/gotm.F90.o' failed
make[2]: *** [gotmlib/CMakeFiles/gotm.dir/gotm.F90.o] Error 1
CMakeFiles/Makefile2:3145: recipe for target 'gotmlib/CMakeFiles/gotm.dir/all' failed
make[1]: *** [gotmlib/CMakeFiles/gotm.dir/all] Error 2
Makefile:129: recipe for target 'all' failed
make: *** [all] Error 2
root@1bd5cfb4f2e1:/opt/build/gotm# make --version
GNU Make 4.1
Built for x86_64-pc-linux-gnu
Copyright (C) 1988-2014 Free Software Foundation, Inc.
License GPLv3+: GNU GPL version 3 or later <http://gnu.org/licenses/gpl.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

###########

### Things to try:
# 1. GNU Make version: on HPC it is 3.82. In docker: 4.1
#######################################################################
#######################################################################


# RUN sed -i '1i add_subdirectory('${BFMDIR}'/bfm_up)' $GOTMDIR/src/CMakeLists.txt && \
#    sed -i '2i add_subdirectory('${BFMDIR}'/bfm_cpl)' $GOTMDIR/src/CMakeLists.txt


# --------------------------
# Copy setup scripts
# --------------------------
# COPY setup_3Dmodels.sh /opt/home/setup_3Dmodels.sh
# COPY cleanup_3Dmodels.sh /opt/home/cleanup_3Dmodels.sh
# RUN chmod +x /opt/home/setup_3Dmodels.sh
# RUN chmod +x /opt/home/cleanup_3Dmodels.sh

# --------------------------
# Default command
# --------------------------
WORKDIR /opt/
CMD ["/bin/bash"]

# docker build -t getm-wad-container:latest .
# docker build --build-arg GIT_USERNAME=yourusername --build-arg GIT_TOKEN=yourtoken  -t getm-wad-container:latest .

# docker run -it getm-wad-container
# mkdir -p ./build/gotm && cd ./build/gotm
# cmake $GOTMDIR -DFABM_BASE=$FABMDIR -DNETCDF_ROOT=/opt/netcdf-fortran-4.4.4
# make install

# grep -r "global_mod" $GOTMDIR
# nano /wad/home/GOTM_SOURCES/gotm_coupled_bfm_2016/src/CMakeLists.txt
# deactivate two lines:
#  add_dependencies(global_mod util)  #GetDelta.F90 depends on Time.F90
#  add_dependencies(gotm bio)

# On HPC:
# module load singularity
# singularity --version
# singularity pull getm-wad-container.sif docker://qingzfly/getm-wad-container:latest
# singularity shell --bind $HOME/home/singularity-workspace:/opt/workspace getm-wad-container.sif # bind the directory, In Singularity, the container filesystem is mostly read-only. 
# Only paths that are bound to your host directories are writable.

# cd /opt/workspace/
# mkdir -p ./build/gotm && cd ./build/gotm
# cmake $GOTMDIR -DFABM_BASE=$FABMDIR -DNETCDF_ROOT=/opt/netcdf-fortran-4.4.4
# make install
# nano /opt/workspace/home/GOTM_SOURCES/gotm_coupled_bfm_2016/src/CMakeLists.txt
# grep -r "global_mod" /opt/workspace/home/GOTM_SOURCES/gotm_coupled_bfm_2016/
