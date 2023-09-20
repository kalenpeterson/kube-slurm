#!/bin/bash
# Test a Wrapper without Slurm, Runs on the same node

# Set Slurm ENV Vars
export SLURM_GPUS=0
export SLURM_JOB_ACCOUNT=unknown
export SLURM_JOB_ID=99
export SLURM_JOB_NAME=slurm-multinode-job
export SLURM_NODEID=99
export SLURMD_NODENAME=nvidia-mgmt01
export SLURM_JOB_NUM_NODES=2
export SLURM_GPUS_PER_NODE=0
export SLURM_JOB_NODELIST=nvidia-mgmt0[1-2]
export KUBE_INIT_TIMEOUT=300

# Define the Image to run
export KUBE_IMAGE=docker.io/kalenpeterson/lambda-openmpi:20230720-v10

# Define the Script to run
export KUBE_SCRIPT=/nas/slurm/data/run-sleep.sh

# Define working directory to use
export KUBE_DATA_VOLUME=/nas/slurm/data

# Set Kubeconfig
export KUBECONFIG=~/.kube/config

# Call the Wrapper
## DO NOT CHANGE ##
../wrappers/kube-slurm-multinode-job-v2.sh
