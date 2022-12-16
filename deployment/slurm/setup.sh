#!/bin/bash
# Setup this node to prepare for a Kube-Slurm Deployment

# Simple Logging function
log () {
    echo $(date) [info] $1
}

# Create a munge.key for the cluster if it doesn't exist.
#  This key will be distributed to the Control and Work nodes
if [[ -s files/munge.key ]]; then
    log "Munge Key already exists in repo, skipping..."
else
    log "Munge Key does not exist in repo, generating with DD"
    dd if=/dev/urandom bs=1 count=1024 > files/munge.key || exit 1
    log "Sucessfully generated new munge.key"
fi

# Build and push Images
IMAGE_TIMESTAMP=$(date +"%Y%m%d-%S")
log "Attempting to build kube-slurm Docker images with Tag ${IMAGE_TIMESTAMP}"
cd docker
./build.sh ${IMAGE_TIMESTAMP}

log "Setup Complete"