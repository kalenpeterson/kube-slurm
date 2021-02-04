#!/bin/bash
## Manage Single-Run Job Pods from Slurm

# Job Details
JOB_NAME=slurm-job-1234-singlerun
JOB_UID=1001
JOB_GID=1001
IMAGE=hello-world
NODE=nvidia-node01
GPU_COUNT=4
TIMEOUT=600

# Globals
NAMESPACE=slurm

## Manage Cleanup for Job Signals
WATCH_LOGS=true
function cleanup () {
  echo "Cleaning up resources"
  WATCH_LOGS=false
  kubectl get pod ${JOB_NAME} -n ${NAMESPACE} 2>/dev/null && kubectl delete pod ${JOB_NAME} -n ${NAMESPACE}
}
trap cleanup EXIT # Normal Exit
trap cleanup SIGTERM # Termination from SLurm

## Ensure Namespace Exists
kubectl get namespace ${NAMESPACE} 2>/dev/null || kubectl create namespace ${NAMESPACE}

## Create Pod
echo "Creating Single-Run Job"
cat <<EOF | kubectl create -n ${NAMESPACE} -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: ${JOB_NAME}
spec:
  restartPolicy: Never
  containers:
  - name: ${JOB_NAME}
    image: ${IMAGE}
  nodeSelector:
    kubernetes.io/hostname: ${NODE}
EOF


## Wait for Container to start
echo "Waiting ${TIMEOUT} seconds for container to be ready"
kubectl wait --for=condition=Initialized --timeout=${TIMEOUT}s -n ${NAMESPACE} pods ${JOB_NAME} || exit 2

## Watch Logs
echo "Container Ready, following logs (updates every 10s)"
while ${WATCH_LOGS}
do
  kubectl logs --since=10s -n ${NAMESPACE} ${JOB_NAME}
  sleep 10
done

exit 0
