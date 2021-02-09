#!/bin/bash
# Test a Wrapper without Slurm, Runs on the same node

# Set Slurm ENV Vars
export SLURM_GPUS=0
export SLURM_JOB_ACCOUNT=unknown
export SLURM_JOB_ID=99
export SLURM_JOB_NAME=slurm-single-job
export SLURM_NODEID=99
export SLURMD_NODENAME=nvidia-node01

# Set Docker Image
export KUBE_IMAGE=registry.local:31500/job-test:latest

# Set your Shared Working Directory
## You're UID/GID must have read/write access to this path
export KUBE_WORK_VOLUME=/nas/volumes/homes/dgx

../wrappers/kube-slurm-image-job.sh
