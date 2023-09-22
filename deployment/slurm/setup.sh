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

log "Setup Complete"