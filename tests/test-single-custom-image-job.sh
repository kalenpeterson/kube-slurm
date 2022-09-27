#!/bin/bash
# Test a Wrapper without Slurm, Runs on the same node

# Set Slurm ENV Vars
export SLURM_GPUS=0
export SLURM_JOB_ACCOUNT=unknown
export SLURM_JOB_ID=99
export SLURM_JOB_NAME=slurm-single-job
export SLURM_NODEID=99
export SLURMD_NODENAME=nvidia-mgmt01
export KUBE_INIT_TIMEOUT=300

# Define the Image to run
export KUBE_IMAGE=docker.io/nginx:latest

# Define the Script to run
export KUBE_SCRIPT="/home/dgx/kube-slurm/containers/slurm-single-tf-job/test.sh"

# Define working directory to use
export KUBE_DATA_VOLUME=/nas/volumes/testvolume

# Call the Wrapper
## DO NOT CHANGE ##
../wrappers/kube-slurm-custom-image-job.sh
