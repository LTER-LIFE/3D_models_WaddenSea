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
    # checkout the latest version:
    # git checkout -b iow_20200609_bfm2016_20250116 remotes/origin/iow_20200609_bfm2016_20250116
    # checkout specific commit:
    git checkout -b iow_20200609_bfm2016_20250116 969dceb73ca9d801c03eb7f218da1d45d5748db3

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
    
    # Replace read_restart_ncdf.F90 in BFM for the coupled model:
    rsync -av --force "$HOME/home/GETM_ERSEM_SETUPS/Container_dependency/read_restart_ncdf.F90" "$HOME/home/BFM_SOURCES/bfm-git/src/getm/read_restart_ncdf.F90"

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
    cp "$HOME/home/GETM_ERSEM_SETUPS/Container_dependency/getm_configure.sh" .
    chmod +x getm_configure.sh
    ./getm_configure.sh

    cd "$HOME/home/GETM_ERSEM_SETUPS/dws_500m" || exit 1
    # --- symbolic links ---
    rm out
    ln -s "$HOME/model_output/active_runs/dws_500m" "$HOME/home/GETM_ERSEM_SETUPS/dws_500m/out"
    
    # --- copy ecological nml files (optional) ---
    # rsync -av /export/lv9/user/qzhan/home/BFM_SOURCES/bfm-git/bfm_nml/ .
    ## To select biological variables output: 'bio_bfm.nml'

    # link hotstart files (may need manually change the user-specific paths)
    #./link_restartfiles
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
    compile_models
    ;;
  2)
    compile_models
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac

# Run the script by:
# Make it executable:
# chmod +x setup_3Dmodels.sh
# ./setup_3Dmodels.sh
