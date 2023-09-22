#!/bin/bash
# Build and Push the image for all defined ENVs

# A version tag is required input and will be appended to the image tag
VERSION_TAG=$1
if [[ -z ${VERSION_TAG} ]]; then
    echo "A Version tag must be provided"
    exit 1
fi

# Define the Base Image Name
IMAGE_NAME=docker.io/kalenpeterson/slurm-docker-cluster

# Simple Logging function
log () {
    echo $(date) [info] $1
}

# Build each environment found in this directory
#  Use the provided my.env.example as a base for your ENV
#  cp my.env.example .my.env" and edit as needed
for env in $(ls -a .*.env |awk -F. '{print $2}')
do
    log "Building ${env} Image"
    cat .${env}.env \
        | xargs printf -- '--build-arg %s\n' \
        | xargs podman build \
            -t ${IMAGE_NAME}:${env}-v${VERSION_TAG} \
            -t ${IMAGE_NAME}:${env}-latest . || exit 1
    
    log "Pushing ${env} Image: ${IMAGE_NAME}:${env}-v${VERSION_TAG}"
    podman push ${IMAGE_NAME}:${env}-v${VERSION_TAG} || exit 1
    log "Pushing ${env} Image: ${IMAGE_NAME}:${env}-latest "
    podman push ${IMAGE_NAME}:${env}-latest || exit 1
done

log "Build(s) Completed"