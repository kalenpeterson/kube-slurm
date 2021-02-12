#!/bin/bash -e
# Build all Images and push to a registry
source ../config/settings.sh

for dir in `ls -d */ | sed 's:/::g'`; do
  cd ${dir}

  echo "Building ${dir}"
  docker build -t ${dir} .
  docker tag ${dir} ${DOCKER_REGISTRY}/${dir}
  docker push ${DOCKER_REGISTRY}/${dir}

 cd -
done
