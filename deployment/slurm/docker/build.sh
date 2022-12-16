#!/bin/bash
VERSION_TAG=$1
IMAGE_NAME=docker.io/kalenpeterson/slurm-docker-cluster

log () {
    echo $(date) [info] $1
}

if [[ -z ${VERSION_TAG} ]]; then
    echo "A Version tag must be provided"
    exit 1
fi

for env in nuc xdl
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