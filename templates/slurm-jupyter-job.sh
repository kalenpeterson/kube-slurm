#!/bin/bash
#SBATCH --job-name=slurm-single-job
#SBATCH --output=/tmp/slurm-single-job.log
#SBATCH --nodelist=dgx-1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
#SBATCH --gpus=2

# Set Docker Image
export KUBE_IMAGE=KUBE_IMAGE=registry.local:31500/slurm-tensorflow:latest

# Set Jupyter Port
export KUBE_TARGET_PORT=8888

# Set your Shared Working Directory
## You're UID/GID must have read/write access to this path
export KUBE_WORK_VOLUME=/nas/volumes/homes/dgx

srun hostname
srun date
srun ../wrappers/kube-slurm-jupyter-job.sh