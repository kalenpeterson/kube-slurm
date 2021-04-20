#!/bin/bash
#SBATCH --job-name=slurm-single-job
#SBATCH --output=/nas/volumes/homes/dgx/slurm-single-job.log
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
#SBATCH --gpus=2

# Define the Image to run
export KUBE_IMAGE=tensorflow:custom

# Define the Script to run
## NOTE: This must be in your home directory
export KUBE_SCRIPT=/home/dgx/kube-slurm/containers/slurm-single-tf-job/test.sh

# Invoke the Job
srun ../wrappers/kube-slurm-custom-image-job.sh