#!/bin/bash
#SBATCH --partition=Test
#SBATCH --job-name=multinodeTestJob
#SBATCH --nodes 2
#SBATCH --output=log-%j.out
#SBATCH --error=logErrors-%j.err

# Define the Image to run
export KUBE_IMAGE=docker.io/kalenpeterson/lambda-openmpi:20230720-v19

# Define the Script to run
export KUBE_SCRIPT=/nas/slurm/data/run-sleep.sh

# Define working directory to use
export KUBE_DATA_VOLUME=/nas/slurm/data

# Set Kubeconfig
export KUBECONFIG=~/.kube/config

# Call the Wrapper
srun /home/dgx/kube-slurm/wrappers/kube-slurm-multinode-job-v2.sh