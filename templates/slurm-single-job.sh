#!/bin/bash
#SBATCH --job-name=slurm-single-job
#SBATCH --output=/nas/volumes/homes/dgx/slurm-single-job.log
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
#SBATCH --gpus=2

# Set Docker Image
export KUBE_IMAGE=registry.local:31500/job-test:latest

# Set your Shared Working Directory
## You're UID/GID must have read/write access to this path
export KUBE_WORK_VOLUME=/nas/volumes/homes/dgx

# Invoke the Job
srun ../wrappers/kube-slurm-image-job.sh