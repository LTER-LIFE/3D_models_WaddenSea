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


# Run the script by:
# Make it executable:
# chmod +x setup_3Dmodels.sh
# $HOME/BFM-GOTM-GETM-FABM/setup_3Dmodels.sh