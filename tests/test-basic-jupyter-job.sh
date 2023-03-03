#!/bin/bash
# Test a Wrapper without Slurm, Runs on the same node

# Set Slurm ENV Vars
export SLURM_GPUS=0
export SLURM_JOB_ACCOUNT=unknown
export SLURM_JOB_ID=99
export SLURM_JOB_NAME=slurm-jupyter-job
export SLURM_NODEID=99
export SLURMD_NODENAME=nvidia-mgmt01

# Set Docker Image
export KUBE_IMAGE=docker.io/jupyter/minimal-notebook:2023-03-03

# Set the Data Volume
export KUBE_DATA_VOLUME=/nas/slurm/data/dgx

# Invoke the Job
../wrappers/kube-slurm-basic-jupyter-job.sh
