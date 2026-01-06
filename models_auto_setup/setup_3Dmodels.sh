#!/bin/sh
# POSIX-compliant shell script to automate cloning of BFM, GOTM, GETM, FABM sources
# Fully portable across Unix systems

# --- PROMPT FOR CREDENTIALS ---
echo "Enter your GitHub username:"
read GIT_USERNAME

echo "Enter your GitHub Personal Access Token:"
# plain sh cannot hide input; token will be visible
read GIT_TOKEN

# --- DIRECTORY SETUP ---
echo "Creating directory structure..."
mkdir -p "$HOME/home/BFM_SOURCES"
mkdir -p "$HOME/home/GOTM_SOURCES"
mkdir -p "$HOME/home/GETM_SOURCES"
mkdir -p "$HOME/home/fabm-git"

# --- STEP (1): Clone BFM ---
echo "Cloning BFM..."
cd "$HOME/home/BFM_SOURCES" || exit 1
git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/jvdmolen/bfm_2016.git"
cd bfm_2016 || exit 1
git checkout -b bfm2016_production_20250827 remotes/origin/bfm2016_production_20250827

# --- STEP (2): Clone GOTM ---
echo "Cloning GOTM..."
cd "$HOME/home/GOTM_SOURCES" || exit 1
git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/jvdmolen/gotm_coupled_bfm_2016.git"
cd gotm_coupled_bfm_2016 || exit 1
git checkout -b master_20210107_couplingGETM_bfm2016_20241126 remotes/origin/master_20210107_couplingGETM_bfm2016_20241126
git submodule update --init --recursive

# --- STEP (3): Clone GETM ---
echo "Cloning GETM..."
cd "$HOME/home/GETM_SOURCES" || exit 1
git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/jvdmolen/getm_coupled_bfm_2016.git"
cd getm_coupled_bfm_2016 || exit 1
git checkout -b iow_20200609_bfm2016_20250116 remotes/origin/iow_20200609_bfm2016_20250116

# add specific checkout if needed later

# --- STEP (4): Clone FABM ---
echo "Cloning FABM..."
cd "$HOME/home/fabm-git" || exit 1
git clone "https://$GIT_USERNAME:$GIT_TOKEN@github.com/fabm-model/fabm.git"
cd fabm || exit 1
# To put the working copy exactly at specific commit, and create a local branch
git checkout -b master_20200610 e1f1f08e42d84f8324f5114924b67ad567719334

echo "==========================================="
echo " Steps 1–4 completed: repositories cloned. "
echo " Next steps: setup environment + compilation."
echo "==========================================="

# --- STEP (5): Set up directory structure
# Such as home/GETM_ERSEM_SETUPS/dws_200m/
# mkdir "$HOME/home/GETM_ERSEM_SETUPS/"
# mkdir "$HOME/home/GETM_ERSEM_SETUPS/Input"

# --- STEP (6): Add settings .sh file: "getm.sh", and modify .bashrc to source shell file in order to set up compilation env
# --- "getm.sh" file can be found in the github repository: https://github.com/NIOZ-QingZ/3D_models_WaddenSea.git

# --- STEP (7): Compile BFM+GOTM
# --- to run test 1D model
# --- To refer Bass's document: "Bass_compile_GOTM_HPC.rtf"
mkdir -p "$HOME/home/build/gotm" && cd "$HOME/home/build/gotm"
cmake $GOTMDIR -DFABM_BASE=$FABMDIR -DCMAKE_INSTALL_PREFIX="$HOME/local/gotm"
make install
# This will produce a GOTM executable at $HOME/local/gotm/bin/gotm
ls $HOME/local/gotm/bin

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


# --- STEP (8): Copy 3D setup from Sonja's directory 
# --- 8.1 copy dir: "dws_200m" from "/export/lv1/user/svanleeuwen/home/setups/"
# cp -r "/export/lv1/user/svanleeuwen/home/setups/dws_200m" "$HOME/home/GETM_ERSEM_SETUPS/"

# --- 8.2 copy file: "dws_200m_info.txt" from "/export/lv1/user/svanleeuwen/home/setups/"; info about "TO DO"
# cp "/export/lv1/user/svanleeuwen/home/setups/dws_200m_info.txt" "$HOME/home/GETM_ERSEM_SETUPS/dws_200m_info.txt"

# --- 8.3 copy file: "move_files" from Johan's folder (any NS usecase), change:
#         line 19: #SBATCH --output=/export/lv9/user/qzhan/move_files.stdout  
# --- 8.4 Modify file: "run_getm_laplace_getmiow_Sonja"; change paths and command for "sbatch ./move_files"


# --- STEP (9): Make some modifications/additions to use BFM
# --- 9.1 Prepare a porosity map based on SIBES&SUBES dataset. An example of such a file is in "/export/lv1/user/jvandermolen/home/GETM_ERSEM_SETUPS/north_west_european_shelf_bfm_jan2025/nwes/Input/Ben_Sedprop.nc"
# --- download SIBES mud_percentage dataset (https://doi.org/10.25850/nioz/7b.b.ug)
# --- download tiff image from Franken (BelowMurkyWaters_Silt)

# --- STEP (10): Compile 3D.
mkdir -p "$HOME/tools/getm/build" && cd "$HOME/tools/getm/build"
cp "$HOME/home/3D_models_WaddenSea/Container/getm_configure.sh" .
chmod +x getm_configure.sh && ./getm_configure.sh

cd "$HOME/home/GETM_ERSEM_SETUPS/dws_200m" && ./compile_all_git

# Run the script by:
# Make it executable:
# chmod +x setup_3Dmodels.sh
# ./setup_3Dmodels.sh