#!/bin/bash
#SBATCH --job-name=gotm_laplace
#SBATCH --output=/path/to/output/log_%j.out
#SBATCH --error=/path/to/output/log_%j.err
#SBATCH --time=12:00:00
#SBATCH --partition=normal
#SBATCH --ntasks=1
#SBATCH --mem=2G

# Load singularity module if needed
module load singularity

# Run the container with GOTM inside
singularity exec $HOME/home/getm-wad-container.sif ./run_gotm_batch_qing

