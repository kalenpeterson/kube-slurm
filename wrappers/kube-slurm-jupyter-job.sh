#!/bin/bash
## Manage Single-Run Job Pods from Slurm

# Job Details
KUBE_JOB_NAME=slurm-job-1234-jupyter
KUBE_JOB_UID=1001
KUBE_JOB_GID=1001
KUBE_IMAGE=slurm-tensorflow:latest
KUBE_TARGET_PORT=8888
KUBE_NODE=nvidia-node01
KUBE_GPU_COUNT=0
KUBE_INIT_TIMEOUT=600
KUBE_POD_MONITOR_INTERVAL=10

# Overrides from SLURM
#KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}

# Globals
KUBE_NAMESPACE=slurm
KUBE_CLUSTER_DNS=nvidia-pod

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
  kubectl get service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} 2>/dev/null && kubectl delete service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE}
}
trap cleanup EXIT # Normal Exit
trap cleanup SIGTERM # Termination from SLurm

## Ensure Namespace Exists
log "Setting up Namespace"
kubectl get namespace ${KUBE_NAMESPACE} 2>/dev/null || kubectl create namespace ${KUBE_NAMESPACE}

## Create Service
log "Creating Notebook NodePort Service"
cat <<EOF | kubectl create -n ${KUBE_NAMESPACE} -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${KUBE_JOB_NAME}
  labels:
    app: ${KUBE_JOB_NAME}
spec:
  type: NodePort
  ports:
  - name: ${KUBE_JOB_NAME}
    port: ${KUBE_TARGET_PORT}
    targetPort: ${KUBE_TARGET_PORT}
    protocol: TCP
  selector:
    app: ${KUBE_JOB_NAME}
EOF

## Generate Random Login Token
JUPYTER_TOKEN=$(openssl rand -base64 24)
log "Generated Jupyter Token: '${JUPYTER_TOKEN}'"

## Generate Notebook URL
NODE_PORT=$(kubectl describe service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} |grep NodePort: |awk '{print $3}' |awk -F/ '{print $1}')
JUPYTER_URL="http://${KUBE_CLUSTER_DNS}:${NODE_PORT}?token=${JUPYTER_TOKEN}"
echo "########################################################"
echo "Your Jupyter Notebook URL will be: ${JUPYTER_URL}"
echo "########################################################"

## Create Pod
log "Deploying Pod"
cat <<EOF | kubectl create -n ${KUBE_NAMESPACE} -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: ${KUBE_JOB_NAME}
  labels:
    app: ${KUBE_JOB_NAME}
spec:
  restartPolicy: Never
  containers:
  - name: ${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    env:
    - name: NB_TOKEN
      value: ${JUPYTER_TOKEN}
    ports:
    - name: jupyter-http
      containerPort: 8888
      protocol: TCP
    #resources:
    #  limits:
    #    nvidia.com/gpu: ${KUBE_GPU_COUNT}
  nodeSelector:
    kubernetes.io/hostname: ${KUBE_NODE}
EOF


## Wait for Container to be Ready
log "Waiting ${KUBE_INIT_TIMEOUT} seconds for Container to be Ready"
kubectl wait --for=condition=ContainersReady --timeout=${KUBE_INIT_TIMEOUT}s -n ${KUBE_NAMESPACE} pods ${KUBE_JOB_NAME} || exit 2

## Monitor Pod status and print logs
log "Container Ready, following logs (updates every ${KUBE_POD_MONITOR_INTERVAL}s)"
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
