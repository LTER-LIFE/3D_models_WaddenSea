#!/bin/sh
# POSIX-compliant cleanup script for BFM/GOTM/GETM/FABM setup
# Prompts user to select which step to roll back

echo "Which step do you want to roll back to? (All subsequent steps will be removed)"
echo "1) Before cloning BFM"
echo "2) Before cloning GOTM"
echo "3) Before cloning GETM"
echo "4) Before cloning FABM"

read STEP

# Convert empty input to 0
[ -z "$STEP" ] && STEP=0

case "$STEP" in
  1)
    echo "Rolling back everything from step 1 onward..."
    rm -rf "$HOME/home/BFM_SOURCES" "$HOME/home/GOTM_SOURCES" "$HOME/home/GETM_SOURCES" "$HOME/home/fabm-git" "$HOME/home/build" "$HOME/tools" 
    ;;
  2)
    echo "Rolling back everything from step 2 onward..."
    rm -rf "$HOME/home/GOTM_SOURCES" "$HOME/home/GETM_SOURCES" "$HOME/home/fabm-git"
    ;;
  3)
    echo "Rolling back from step 3 onward..."
    rm -rf "$HOME/home/GETM_SOURCES" "$HOME/home/fabm-git"
    ;;
  4)
    echo "Rolling back from step 4 onward..."
    rm -rf "$HOME/home/fabm-git"
    ;;
  *)
    echo "No valid step selected. Nothing removed."
    ;;
esac

echo "Cleanup completed."

# Run the script by:
# Make it executable:
# chmod +x cleanup_3Dmodels.sh
# $HOME/BFM-GOTM-GETM-FABM/cleanup_3Dmodels.sh