#!/bin/sh
# POSIX-compliant shell script to automate cloning of BFM, GOTM, GETM, FABM sources
# Mode 1: clean + clone
# Mode 2: compile only (keep git repositories)

echo "==========================================="
echo " BFM / GOTM / GETM / FABM setup"
echo "==========================================="
echo "Choose an action:"
echo "1) Clean + clone all git repositories"
echo "2) Compile only (keep existing repositories)"
echo "-------------------------------------------"
printf "Enter choice [1-2]: "
read ACTION

[ -z "$ACTION" ] && ACTION=0

###############################################################################
# BASIC CHECK: SSH ACCESS (needed for cloning)
###############################################################################
check_ssh(){
echo "Checking SSH access to GitHub..."
if ! ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
    echo "ERROR: SSH authentication to GitHub failed."
    echo "Make sure your SSH key is added to GitHub and ssh-agent is running."
    exit 1
fi
echo "SSH authentication OK."
}

###############################################################################
# CLEANUP (used before cloning)
###############################################################################
cleanup_repos() {
    echo "Cleaning existing repositories and build directories..."
    rm -rf "$HOME/home/BFM_SOURCES"
    rm -rf "$HOME/home/GOTM_SOURCES"
    rm -rf "$HOME/home/GETM_SOURCES"
    rm -rf "$HOME/home/fabm-git"
    rm -rf "$HOME/home/build"
    rm -rf "$HOME/tools"
    rm -rf "$HOME/local"
    rm -rf "$HOME/home/bfm-git" "$HOME/home/gotm-git" "$HOME/home/getm-git"
}

###############################################################################
# CLONING
###############################################################################
clone_repos() {

# --- DIRECTORY SETUP ---
    echo "Creating directory structure..."
    mkdir -p "$HOME/home/BFM_SOURCES"
    mkdir -p "$HOME/home/GOTM_SOURCES"
    mkdir -p "$HOME/home/GETM_SOURCES"
    mkdir -p "$HOME/home/fabm-git"

    # --- BFM ---
    echo "Cloning BFM..."
    cd "$HOME/home/BFM_SOURCES" || exit 1
    git clone "git@github.com:jvdmolen/bfm_2016.git"
    cd bfm_2016 || exit 1
    git checkout -b bfm2016_production_20250827 remotes/origin/bfm2016_production_20250827


    # --- GOTM ---
    echo "Cloning GOTM..."
    cd "$HOME/home/GOTM_SOURCES" || exit 1
    git clone "git@github.com:jvdmolen/gotm_coupled_bfm_2016.git"
    cd gotm_coupled_bfm_2016 || exit 1
    git checkout -b master_20210107_couplingGETM_bfm2016_20241126 remotes/origin/master_20210107_couplingGETM_bfm2016_20241126
    git submodule update --init --recursive

    # --- GETM ---
    echo "Cloning GETM..."
    cd "$HOME/home/GETM_SOURCES" || exit 1
    git clone "git@github.com:jvdmolen/getm_coupled_bfm_2016.git"
    cd getm_coupled_bfm_2016 || exit 1
    git checkout -b iow_20200609_bfm2016_20250116 remotes/origin/iow_20200609_bfm2016_20250116

    # --- FABM ---
    echo "Cloning FABM..."
    cd "$HOME/home/fabm-git" || exit 1
    git clone "git@github.com:fabm-model/fabm.git"
    cd fabm || exit 1
    # To put the working copy exactly at specific commit, and create a local branch
    git checkout -b master_20200610 e1f1f08e42d84f8324f5114924b67ad567719334

    # --- symbolic links ---
    ln -s "$HOME/home/BFM_SOURCES/bfm_2016" "$HOME/home/BFM_SOURCES/bfm-git"
    ln -s "$HOME/home/GOTM_SOURCES/gotm_coupled_bfm_2016" "$HOME/home/gotm-git"
    ln -s "$HOME/home/GETM_SOURCES/getm_coupled_bfm_2016" "$HOME/home/getm-git"

    echo "==========================================="
    echo " Cloning completed successfully"
    echo "==========================================="
}


###############################################################################
# COMPILATION
###############################################################################
compile_models(){
    echo "Starting compilation..."
    
    # --- Clean build directories ---
    rm -rf "$HOME/home/build"
    rm -rf "$HOME/tools"
    rm -rf "$HOME/local"

    # --- Compile GOTM (1D) ---
    mkdir -p "$HOME/home/build/gotm"
    cd "$HOME/home/build/gotm" || exit 1
    mkdir -p "$HOME/local/gotm"

    cmake "$GOTMDIR" \
        -DFABM_BASE="$FABMDIR" \
        -DCMAKE_INSTALL_PREFIX="$HOME/local/gotm"
    
    make install # This will produce a GOTM executable at $HOME/local/gotm/bin/gotm
    ls "$HOME/local/gotm/bin"        

    # --- Compile GETM (3D) ---
    mkdir -p "$HOME/tools"
    cd "$HOME/tools" || exit 1
    cp -a "/export/lv1/user/jvandermolen/tools/bbpy" .

    mkdir -p "$HOME/tools/getm/build"
    cd "$HOME/tools/getm/build" || exit 1
    cp "$HOME/home/GETM_ERSEM_SETUPS/Container/getm_configure.sh" .
    chmod +x getm_configure.sh
    ./getm_configure.sh

    cd "$HOME/home/GETM_ERSEM_SETUPS/dws_200m" || exit 1
    ./link_restart_files
    ./compile_all_git

    echo "==========================================="
    echo " Compilation completed successfully"
    echo "==========================================="
}



###############################################################################
# MAIN DISPATCH
###############################################################################
case "$ACTION" in
  1)
    check_ssh
    cleanup_repos
    clone_repos
    ;;
  2)
    compile_models
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# to debug:
# BFM_SOURCES/bfm-git/src/getm/read_restart_ncdf.F90

#      LEVEL1 "joff/jmax",joff/jmax
#      ioff_l=ioff-ioff_0
#      joff_l=joff-joff_0
#      LEVEL1 "jmax,joff,joff_0,joff_l",jmax,joff,joff_0,joff_l      
#!possibility to use "old" netcdf restart files...
#      if (ioff_0_from_file .eq.-9999) then
#         ioff_0=0;joff_0=0
#         joff_l=jmax*(joff/jmax+1)
#         LEVEL1 "joff_l",joff_l
#!possibility to use "old" netcdf restart files...
#      if (ioff_0_from_file .eq.-9999) then
#         ioff_0=0;joff_0=0
#         joff_l=jmax*(joff/jmax+1)
#         if (joff.le.0) then
#            joff_l=0
#         endif
#         LEVEL1 "joff_l",joff_l
#      else
#!       [ij]off_0 : relative difference of position the sw-corner of the
#!                          subdomain in the sw corner of the domain.
#        ioff_0=ioff_0-ioff_0_from_file
#        joff_0=joff_0-joff_0_from_file
#      endif

# --- to run a test case, e.g., OysterGrounds
# mkdir -p "$HOME/home/gotm-cases/nov2024_bfm2016" && cd "$HOME/home/gotm-cases/nov2024_bfm2016"
# rsync -av /export/lv1/user/jvandermolen/home/gotm-cases/nov2024_bfm2016/OysterGrounds .

# grep -r jvandermolen . # find paths that include jvandermolen, change it to your user
# nano gotmrun.nml
# nano run_gotm_laplace
# sbatch ./run_gotm_laplace
# squeue
# ls log*
# tail -F log.out

# --- STEP: Copy 3D setup from Sonja's directory 
# --- copy dir: "dws_200m" from "/export/lv1/user/svanleeuwen/home/setups/"
# cp -r "/export/lv1/user/svanleeuwen/home/setups/dws_200m" "$HOME/home/GETM_ERSEM_SETUPS/"

# --- copy file: "dws_200m_info.txt" from "/export/lv1/user/svanleeuwen/home/setups/"; info about "TO DO"
# cp "/export/lv1/user/svanleeuwen/home/setups/dws_200m_info.txt" "$HOME/home/GETM_ERSEM_SETUPS/dws_200m_info.txt"

# --- copy file: "move_files" from Johan's folder (any NS usecase), change:
#         line 19: #SBATCH --output=/export/lv9/user/qzhan/move_files.stdout  
# --- Modify file: "run_getm_laplace_getmiow_Sonja"; change paths and command for "sbatch ./move_files"


# --- STEP: Make some modifications/additions to use BFM
# --- Prepare a porosity map based on SIBES&SUBES dataset. An example of such a file is in "/export/lv1/user/jvandermolen/home/GETM_ERSEM_SETUPS/north_west_european_shelf_bfm_jan2025/nwes/Input/Ben_Sedprop.nc"
# --- download SIBES mud_percentage dataset (https://doi.org/10.25850/nioz/7b.b.ug)
# --- download tiff image from Franken (BelowMurkyWaters_Silt)

# Run the script by:
# Make it executable:
# chmod +x setup_3Dmodels.sh
# ./setup_3Dmodels.sh
