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
export KUBE_IMAGE=docker.io/kalenpeterson/slurm-tensorflow:v1.0

# Set the Data Volume
export KUBE_JUPYTER_WORK_VOLUME=/home/dgx

# Invoke the Job
../wrappers/kube-slurm-jupyter-job.sh
