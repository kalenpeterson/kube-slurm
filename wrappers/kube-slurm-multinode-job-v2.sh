#!/bin/bash
## Manage Single-Run Job Pods from Slurm
#source ../config/settings.sh

## Manage Logging
function log () {
  TIMESTAMP=$(date "+%T")
  echo "# KUBE-SLURM: [${SLURMD_NODENAME}] (${TIMESTAMP}): ${1}"
}

# Print Slurm ENV Vars
echo
log "Slurm ENV Vars:"
log "SLURM_GPUS: ${SLURM_GPUS:=0}"
log "SLURM_JOB_ACCOUNT: ${SLURM_JOB_ACCOUNT}"
log "SLURM_JOB_ID: ${SLURM_JOB_ID}"
log "SLURM_JOB_NAME: ${SLURM_JOB_NAME}"
log "SLURM_NODEID: ${SLURM_NODEID}"
log "SLURMD_NODENAME: ${SLURMD_NODENAME}"
log "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID}"
log "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
log "SLURM_JOB_NUM_NODES: ${SLURM_JOB_NUM_NODES:=0}"
log "SLURM_GPUS_PER_NODE: ${SLURM_GPUS_PER_NODE:=0}"
log "PATH: ${PATH}"

# Set Job Details
KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}-${SLURMD_NODENAME}
KUBE_JOB_UID=$(id -u)
KUBE_JOB_GID=$(id -g)
KUBE_JOB_USERNAME=$(id -nu)
KUBE_NODE=${SLURMD_NODENAME}
KUBE_GPU_COUNT=${SLURM_GPUS}
KUBE_INIT_TIMEOUT=${KUBE_INIT_TIMEOUT:=600}
KUBE_POD_MONITOR_INTERVAL=${KUBE_POD_MONITOR_INTERVAL:=10}
KUBE_NAMESPACE=${KUBE_NAMESPACE:=slurm}
USER_HOME=${HOME}
KUBE_SCRIPT=${KUBE_SCRIPT}
KUBE_SCRIPT_VARS=${KUBE_SCRIPT_VARS}
KUBE_IMAGE=${KUBE_IMAGE}
KUBE_CLUSTER_DNS=${KUBE_CLUSTER_DNS:=nvidia-pod}
KUBE_DATA_VOLUME=${KUBE_DATA_VOLUME}
KUBE_JOB_FSGID=${KUBE_JOB_FSGID}

# Setup Kubeconfig
export KUBECONFIG=${KUBECONFIG:=/data/erisxdl/kube-slurm/config/kube.config}

# Print Kube ENV Vars
echo 
log "Kube ENV Vars:"
log "KUBE_JOB_NAME: ${KUBE_JOB_NAME}"
log "KUBE_JOB_UID: ${KUBE_JOB_UID}"
log "KUBE_JOB_GID: ${KUBE_JOB_GID}"
log "KUBE_JOB_USERNAME: ${KUBE_JOB_USERNAME}"
log "KUBE_IMAGE: ${KUBE_IMAGE}"
log "KUBE_DATA_VOLUME: ${KUBE_DATA_VOLUME}"
log "KUBE_NODE: ${KUBE_NODE}"
log "KUBE_GPU_COUNT: ${KUBE_GPU_COUNT}"
log "KUBE_INIT_TIMEOUT: ${KUBE_INIT_TIMEOUT}"
log "KUBE_POD_MONITOR_INTERVAL: ${KUBE_POD_MONITOR_INTERVAL}"
log "KUBE_NAMESPACE: ${KUBE_NAMESPACE}"
log "USER_HOME: ${USER_HOME}"
log "KUBE_SCRIPT: ${KUBE_SCRIPT}"
log "KUBE_SCRIPT_VARS: ${KUBE_SCRIPT_VARS}"
log "KUBE_CLUSTER_DNS: ${KUBE_CLUSTER_DNS}"
log "KUBE_JOB_NODE_LIST: ${KUBE_JOB_NODE_LIST}"

## Manage Cleanup for Job Signals
WATCH_POD=true
function cleanup () {
  log "Cleaning up resources"
  WATCH_POD=false
  log "Deleting Service"
  kubectl get service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} 2>/dev/null && kubectl delete service ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE}
  log "Deleting Pod, please wait for termination to complete"
  kubectl get pod ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE} 2>/dev/null && kubectl delete pod ${KUBE_JOB_NAME} -n ${KUBE_NAMESPACE}
  log "Completed cleanup"
}
trap cleanup EXIT # Normal Exit
trap cleanup SIGTERM # Termination from Slurm

## Get pod error messages when they fail
function get_pod_error () {
  NAMESPACE=$1
  POD=$2
  log "Collecting POD Events..."
  kubectl describe pod -n ${NAMESPACE} ${POD} |grep -A20 Events
  log "Collecting POD Logs"
  kubectl logs -n ${NAMESPACE} ${POD}
}

## Select OpenMPI Controller and Workers
OPENMPI_CONTROLLER=$(scontrol show hostnames "${SLURM_JOB_NODELIST}" |head -n1)
log "Node ${OPENMPI_CONTROLLER} has been selected as the OpenMPI Controller"
if [[ $SLURMD_NODENAME == $OPENMPI_CONTROLLER ]]; then
  OPENMPI_POD_TYPE="controller"
else
  OPENMPI_POD_TYPE="worker"
fi
log "OPENMPI_POD_TYPE: ${OPENMPI_POD_TYPE}"

# Set the connection timeout between OpenMPI Pods
OPENMPI_CONNECTION_TIMEOUT=${OPENMPI_CONNECTION_TIMEOUT:=300}
log "OPENMPI_CONNECTION_TIMEOUT: ${OPENMPI_CONNECTION_TIMEOUT}"

## Check Data Volume and get it's GID
log "Checking GID of KUBE_DATA_VOLUME"
KUBE_JOB_FSGID=$(getfacl -nat "${KUBE_DATA_VOLUME}" 2>/dev/null |grep ^GROUP |awk '{print $2}')
log "KUBE_JOB_FSGID: ${KUBE_JOB_FSGID}"
if [[ "${KUBE_JOB_FSGID}" == "" || "${DATA_VOLUME_GID}" == "0" ]]; then
  log "ERROR: Failed to get GID of KUBE_DATA_VOLUME OR GID was 0"
  exit 1
fi
KUBE_JOB_FS_GROUPNAME=$(getent group ${KUBE_JOB_FSGID} | cut -d: -f1)
log "KUBE_JOB_FS_GROUPNAME: ${KUBE_JOB_FS_GROUPNAME}"

## Ensure Namespace Exists
log "Setting up Namespace"
kubectl get namespace ${KUBE_NAMESPACE} 2>/dev/null || kubectl create namespace ${KUBE_NAMESPACE}

## Generate GPU Line (Useful for when you do not need ANY GPUs)
if [[ $SLURM_GPUS_PER_NODE -gt 0 ]]
then
  KUBE_RESOURCE_LIMITS="resources: {limits: {nvidia.com/gpu: ${SLURM_GPUS_PER_NODE}, rdma/hca_shared_devices_a: 8}}"
else
  KUBE_RESOURCE_LIMITS=''
fi

## Create Service
log "Creating openmpi SSH Service"
cat <<EOF | kubectl create -n ${KUBE_NAMESPACE} -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${KUBE_JOB_NAME}
  labels:
    app: ${KUBE_JOB_NAME}
spec:
  type: ClusterIP
  ports:
  - name: sshd
    port: 2222
    targetPort: 2222
    protocol: TCP
  selector:
    app: ${KUBE_JOB_NAME}
EOF

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
      path: "${KUBE_DATA_VOLUME}"
  - name: home
    hostPath:
      type: Directory
      path: "${USER_HOME}"
#  - name: dshm
#    emptyDir:
#      medium: Memory
#      sizeLimit: 32Gi
  - name: currentuser
    emptyDir:
      sizeLimit: 500Mi
  restartPolicy: Never
  shareProcessNamespace: true
  containers:
  - name: ${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    securityContext:
      runAsUser: ${KUBE_JOB_UID}
      runAsGroup: ${KUBE_JOB_FSGID}
      capabilities:
        add: ["IPC_LOCK"]
    workingDir: "${USER_HOME}"
    command: ["/usr/local/bin/entrypoint.sh"]
    args:
      - ${OPENMPI_POD_TYPE}
#    command: ["sleep","infinity"]
    ports:
    - name: sshd
      containerPort: 2222
      protocol: TCP
    env:
    - name: HOME
      value: "${USER_HOME}"
    - name: KUBE_SCRIPT
      value: "${KUBE_SCRIPT}"
    - name: SLURM_ARRAY_TASK_ID
      value: "${SLURM_ARRAY_TASK_ID}"
    - name: KUBE_SCRIPT_VARS
      value: "${KUBE_SCRIPT_VARS}"
    - name: OPENMPI_CONTROLLER
      value: "${OPENMPI_CONTROLLER}"
    - name: OPENMPI_CONNECTION_TIMEOUT
      value: "${OPENMPI_CONNECTION_TIMEOUT}"
    - name: SLURM_JOB_NODELIST
      value: "${SLURM_JOB_NODELIST}"
    - name: SLURM_JOB_NUM_NODES
      value: "${SLURM_JOB_NUM_NODES}"
    - name: SLURM_GPUS_PER_NODE
      value: "${SLURM_GPUS_PER_NODE}"
    - name: SLURM_JOB_ID
      value: "${SLURM_JOB_ID}"
    volumeMounts:
    - name: apps
      mountPath: /apps
    - name: data
      mountPath: "${KUBE_DATA_VOLUME}"
    - name: home
      mountPath: "${USER_HOME}"
#    - name: dshm
#      mountPath: /dev/shm
    - name: currentuser
      mountPath: /currentuser
    - name: currentuser
      mountPath: /etc/passwd
      subPath: passwd
    - name: currentuser
      mountPath: /etc/group
      subPath: group
    ${KUBE_RESOURCE_LIMITS}
  initContainers:
  - name: init-${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    securityContext:
      runAsUser: 0
      runAsGroup: 0
      allowPrivilegeEscalation: true
    command: ["/usr/local/bin/entrypoint.sh"]
    args:
      - "init"
    env:
    - name: KUBE_JOB_UID
      value: "${KUBE_JOB_UID}"
    - name: KUBE_JOB_FSGID
      value: "${KUBE_JOB_FSGID}"
    - name: KUBE_JOB_USERNAME
      value: "${KUBE_JOB_USERNAME}"
    - name: KUBE_JOB_FS_GROUPNAME
      value: "${KUBE_JOB_FS_GROUPNAME}"
    - name: USER_HOME
      value: "${USER_HOME}"
    volumeMounts:
    - name: currentuser
      mountPath: /currentuser
  nodeSelector:
    kubernetes.io/hostname: ${KUBE_NODE}
EOF


## Wait for Pod to Initialize
log "Waiting ${KUBE_INIT_TIMEOUT} seconds for Pod to Initialize"
kubectl wait --for=condition=ready --timeout=${KUBE_INIT_TIMEOUT}s -n ${KUBE_NAMESPACE} pods ${KUBE_JOB_NAME}
RC=$?

## Check if Pod Started
if [[ $RC -ne 0 ]]; then
  log "Pod initilization failed or timed out, see following for troubleshooting"
  get_pod_error ${KUBE_NAMESPACE} ${KUBE_JOB_NAME}
  exit 2
fi

## Monitor Pod status and print logs
log "Pod Initialized, following logs (updates every ${KUBE_POD_MONITOR_INTERVAL}s)"
while ${WATCH_POD}
do

  # Get latest logs
  kubectl logs --since=${KUBE_POD_MONITOR_INTERVAL}s -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} 2>/dev/null

  # Check if the Container has stopped. If it has, return the container's exit code
  # NOTE: This has been modified to return to "last" container's status. We added init containers, and this will ignore them
  #       if more containers are added, you'll need to find a way to deal with that
  POD_STATUS=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep State: |awk '{print $2}' |tail -1)
  if [[ ${POD_STATUS} == 'Terminated' ]]; then
    POD_EXIT_CODE=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep 'Exit Code:' |awk '{print $3}' |tail -1)
    log "Container terminated with exit code '${POD_EXIT_CODE}'"
    exit ${POD_EXIT_CODE}
  fi
  sleep ${KUBE_POD_MONITOR_INTERVAL}
done

exit 0
