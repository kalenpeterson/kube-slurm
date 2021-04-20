#!/bin/bash
# Test a Wrapper without Slurm, Runs on the same node

# Set Slurm ENV Vars
export SLURM_GPUS=0
export SLURM_JOB_ACCOUNT=unknown
export SLURM_JOB_ID=99
export SLURM_JOB_NAME=slurm-single-job
export SLURM_NODEID=99
export SLURMD_NODENAME=nvidia-node01

# Define the Image to run
export KUBE_IMAGE=tensorflow:custom

# Define the Script to run
export KUBE_SCRIPT=/home/dgx/kube-slurm/containers/slurm-single-tf-job/test.sh

# Call the Wrapper
## DO NOT CHANGE ##
../wrappers/kube-slurm-custom-image-job.sh
