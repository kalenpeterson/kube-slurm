#!/bin/bash
#SBATCH --job-name=slurm-jupyter-job
#SBATCH --output=//nas/volumes/homes/dgx/slurm-jupyter-job.log
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
#SBATCH --gpus=2

# Set Docker Image
export KUBE_IMAGE=KUBE_IMAGE=registry.local:31500/slurm-tensorflow:latest

# Invoke the Job
srun ../wrappers/kube-slurm-jupyter-job.sh