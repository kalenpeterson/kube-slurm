#!/bin/bash
## Manage Single-Run Job Pods from Slurm

# Job Details
KUBE_JOB_NAME=slurm-job-1234-singlerun
KUBE_JOB_UID=1001
KUBE_JOB_GID=1001
KUBE_IMAGE=hello-world
KUBE_NODE=nvidia-node01
KUBE_GPU_COUNT=0
KUBE_INIT_TIMEOUT=600
KUBE_POD_MONITOR_INTERVAL=10

# Overrides from SLURM
#KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}

# Globals
KUBE_NAMESPACE=slurm

## Manage Logging
function log () {
  echo "# KUBE-SLURM: ${1}"
} 

## Manage Cleanup for Job Signals
WATCH_POD=true
function cleanup () {
  log "Cleaning up resources"
  WATCH_POD=false
  kubectl get pod ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} 2>/dev/null && kubectl delete pod ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE}
}
trap cleanup EXIT # Normal Exit
trap cleanup SIGTERM # Termination from SLurm

## Ensure Namespace Exists
log "Setting up Namespace"
kubectl get namespace ${KUBE_NAMESPACE} 2>/dev/null || kubectl create namespace ${KUBE_NAMESPACE}

## Create Pod
log "Deploying Pod"
cat <<EOF | kubectl create -n ${KUBE_NAMESPACE} -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: ${KUBE_JOB_NAME}
spec:
  restartPolicy: Never
  containers:
  - name: ${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    #resources:
    #  limits:
    #    nvidia.com/gpu: ${KUBE_GPU_COUNT}
  nodeSelector:
    kubernetes.io/hostname: ${KUBE_NODE}
EOF


## Wait for Pod to Initialize
log "Waiting ${KUBE_INIT_TIMEOUT} seconds for Pod to Initialize"
kubectl wait --for=condition=Initialized --timeout=${KUBE_INIT_TIMEOUT}s -n ${KUBE_NAMESPACE} pods ${KUBE_JOB_NAME} || exit 2

## Monitor Pod status and print logs
log "Pod Initialized, following logs (updates every ${KUBE_POD_MONITOR_INTERVAL}s)"
while ${WATCH_POD}
do

  # Get latest logs
  kubectl logs --since=${KUBE_POD_MONITOR_INTERVAL}s -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} 2>/dev/null

  # Check if the Container has stopped. If it has, return the container's exit code
  POD_STATUS=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep State: |awk '{print $2}')
  if [[ ${POD_STATUS} == 'Terminated' ]]; then
    POD_EXIT_CODE=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep 'Exit Code:' |awk '{print $3}')
    log "Container terminated with exit code '${POD_EXIT_CODE}'"
    exit ${POD_EXIT_CODE}
  fi
  sleep ${KUBE_POD_MONITOR_INTERVAL}
done

exit 0
