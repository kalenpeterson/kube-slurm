#!/bin/bash
## Manage Jupyter Job Pods from Slurm
source ../config/settings.sh

# Print Slurm ENV Vars
echo
echo "Slurm ENV Vars:"
echo "SLURM_GPUS: ${SLURM_GPUS}"
echo "SLURM_JOB_ACCOUNT: ${SLURM_JOB_ACCOUNT}"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SLURM_JOB_NAME: ${SLURM_JOB_NAME}"
echo "SLURM_NODEID: ${SLURM_NODEID}"
echo "SLURMD_NODENAME: ${SLURMD_NODENAME}"

# Set Job Details
KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}
KUBE_JOB_UID=$(id -u)
KUBE_JOB_GID=$(id -g)
KUBE_JOB_USER=$(id -un)
KUBE_JOB_GROUP=$(id -gn)
KUBE_NODE=${SLURMD_NODENAME}
KUBE_GPU_COUNT=${SLURM_GPUS}
KUBE_INIT_TIMEOUT=${KUBE_INIT_TIMEOUT}
KUBE_POD_MONITOR_INTERVAL=${KUBE_POD_MONITOR_INTERVAL}
KUBE_NAMESPACE=${KUBE_NAMESPACE}
KUBE_CLUSTER_DNS=${KUBE_CLUSTER_DNS}
KUBE_INGRESS_PREFIX="/jupyter"
USER_HOME=${HOME}

# Setup Kubeconfig
export KUBECONFIG=${KUBECONFIG}

# Print Kube ENV Vars
echo
echo "Kube ENV Vars:"
echo "KUBE_JOB_NAME: ${KUBE_JOB_NAME}"
echo "KUBE_JOB_UID: ${KUBE_JOB_UID}"
echo "KUBE_JOB_GID: ${KUBE_JOB_GID}"
echo "KUBE_IMAGE: ${KUBE_IMAGE}"
echo "KUBE_WORK_VOLUME: ${KUBE_WORK_VOLUME}"
echo "KUBE_TARGET_PORT: ${KUBE_TARGET_PORT}"
echo "KUBE_NODE: ${KUBE_NODE}"
echo "KUBE_GPU_COUNT: ${KUBE_GPU_COUNT}"
echo "KUBE_INIT_TIMEOUT: ${KUBE_INIT_TIMEOUT}"
echo "KUBE_POD_MONITOR_INTERVAL: ${KUBE_POD_MONITOR_INTERVAL}"
echo "KUBE_NAMESPACE: ${KUBE_NAMESPACE}"
echo "KUBE_CLUSTER_DNS: ${KUBE_CLUSTER_DNS}"
echo "KUBE_INGRESS_PREFIX: ${KUBE_INGRESS_PREFIX}"
echo "User Home: ${USER_HOME}"

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
  kubectl get ingress ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} 2>/dev/null && kubectl delete ingress ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE}
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
JUPYTER_TOKEN=$(openssl rand -hex 24)
log "Generated Jupyter Token: '${JUPYTER_TOKEN}'"

## Create Ingress
log "Creating Notebook Ingress"
cat <<EOF | kubectl create -n ${KUBE_NAMESPACE} -f -
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: ${KUBE_JOB_NAME}
spec:
  rules:
  - host: ${KUBE_CLUSTER_DNS}
    http:
      paths:
      - path: "${KUBE_INGRESS_PREFIX}/${KUBE_JOB_NAME}"
        backend:
          serviceName: ${KUBE_JOB_NAME}
          servicePort: ${KUBE_TARGET_PORT}
EOF

## Generate Notebook URL (Ingress)
#NODE_PORT=$(kubectl describe service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} |grep NodePort: |awk '{print $3}' |awk -F/ '{print $1}')
JUPYTER_URL="https://${KUBE_CLUSTER_DNS}${KUBE_INGRESS_PREFIX}/${KUBE_JOB_NAME}?token=${JUPYTER_TOKEN}"
#JUPYTER_URL="http://${KUBE_CLUSTER_DNS}:${NODE_PORT}/?token=${JUPYTER_TOKEN}"
echo "########################################################"
echo "Your Jupyter Notebook URL will be: ${JUPYTER_URL}"
echo "########################################################"

## Generate GPU Line (Useful for when you do not need ANY GPUs)
if [[ $KUBE_GPU_COUNT -gt 0 ]]
then
  KUBE_GPU_LIMIT="resources: {limits: {nvidia.com/gpu: ${KUBE_GPU_COUNT}}}"
else
  KUBE_GPU_LIMIT=''
fi

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
  volumes:
  - name: apps
    hostPath:
      type: Directory
      path: /apps
  - name: data
    hostPath:
      type: Directory
      path: /data
  - name: workspace
    hostPath:
      type: Directory
      path: ${USER_HOME}
  restartPolicy: Never
  containers:
  - name: ${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    volumeMounts:
    - name: apps
      mountPath: /apps
    - name: data
      mountPath: /data
    - name: workspace
      mountPath: /workspace
    env:
    - name: NB_TOKEN
      value: ${JUPYTER_TOKEN}
    - name: NB_USER
      value: ${KUBE_JOB_USER}
    - name: NB_UID
      value: "${KUBE_JOB_UID}"
    - name: NB_GROUP
      value: ${KUBE_JOB_GROUP}
    - name: NB_GID
      value: "${KUBE_JOB_GID}"
    - name: NB_PREFIX
      value: "${KUBE_INGRESS_PREFIX}/${KUBE_JOB_NAME}"
    ports:
    - name: jupyter-http
      containerPort: ${KUBE_TARGET_PORT}
      protocol: TCP
    ${KUBE_GPU_LIMIT}
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
