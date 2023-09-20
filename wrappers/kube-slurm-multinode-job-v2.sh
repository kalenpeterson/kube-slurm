#!/bin/bash
## Manage Single-Run Job Pods from Slurm
#source ../config/settings.sh

# Print Slurm ENV Vars
echo
echo "Slurm ENV Vars:"
echo "SLURM_GPUS: ${SLURM_GPUS}"
echo "SLURM_JOB_ACCOUNT: ${SLURM_JOB_ACCOUNT}"
echo "SLURM_JOB_ID: ${SLURM_JOB_ID}"
echo "SLURM_JOB_NAME: ${SLURM_JOB_NAME}"
echo "SLURM_NODEID: ${SLURM_NODEID}"
echo "SLURMD_NODENAME: ${SLURMD_NODENAME}"
echo "SLURM_ARRAY_TASK_ID: ${SLURM_ARRAY_TASK_ID}"

echo "SLURM_JOB_NODELIST: ${SLURM_JOB_NODELIST}"
echo "SLURM_JOB_NUM_NODES: ${SLURM_JOB_NUM_NODES}"
echo "SLURM_GPUS_PER_NODE: ${SLURM_GPUS_PER_NODE}"

# Set Job Details
KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}
KUBE_JOB_UID=$(id -u)
KUBE_JOB_GID=$(id -g)
JUBE_JOB_USERNAME=$(id -nu)
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

KUBE_JOB_NODE_LIST=($(scontrol show hostnames "${SLURM_JOB_NODELIST}"))

# Setup Kubeconfig
export KUBECONFIG=${KUBECONFIG:=/data/erisxdl/kube-slurm/config/kube.config}

# Print Kube ENV Vars
echo 
echo "Kube ENV Vars:"
echo "KUBE_JOB_NAME: ${KUBE_JOB_NAME}"
echo "KUBE_JOB_UID: ${KUBE_JOB_UID}"
echo "KUBE_JOB_GID: ${KUBE_JOB_GID}"
echo "KUBE_IMAGE: ${KUBE_IMAGE}"
echo "KUBE_DATA_VOLUME: ${KUBE_DATA_VOLUME}"
echo "KUBE_NODE: ${KUBE_NODE}"
echo "KUBE_GPU_COUNT: ${KUBE_GPU_COUNT}"
echo "KUBE_INIT_TIMEOUT: ${KUBE_INIT_TIMEOUT}"
echo "KUBE_POD_MONITOR_INTERVAL: ${KUBE_POD_MONITOR_INTERVAL}"
echo "KUBE_NAMESPACE: ${KUBE_NAMESPACE}"
echo "USER_HOME: ${USER_HOME}"
echo "KUBE_SCRIPT: ${KUBE_SCRIPT}"
echo "KUBE_SCRIPT_VARS: ${KUBE_SCRIPT_VARS}"
echo "KUBE_CLUSTER_DNS: ${KUBE_CLUSTER_DNS}"
echo "KUBE_JOB_NODE_LIST: ${KUBE_JOB_NODE_LIST}"

## Manage Logging
function log () {
  echo "# KUBE-SLURM: ${1}"
}

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

function get_pod_error () {
  NAMESPACE=$1
  POD=$2
  log "Collecting POD Events..."
  kubectl describe pod -n ${NAMESPACE} ${POD} |grep -A20 Events
  log "Collecting POD Logs"
  kubectl logs -n ${NAMESPACE} ${POD}
}

## Elect OpemMPI Leader
### Execition will continue from the elected controller
### Other nodes will sleep and wait for jobs
OPENMPI_CONTROLLER=${KUBE_JOB_NODE_LIST[0]}
log "Node ${OPENMPI_CONTROLLER} has been selected as the OpenMPI Controller"
if [[ $SLURMD_NODENAME == $OPENMPI_CONTROLLER ]]; then
  log "I am ${SLURMD_NODENAME}, this node will be the OpemMPI Controller for this Multinode Job Run"
  log "Continuing execution from this node"
else
  log "I am ${SLURMD_NODENAME}, this node will not be the OpenMPI Controller"
  log "Going to sleep, waiting for workload instructions from OpenMPI..."
  sleep infinity
fi

## Check Data Volume and get it's GID
log "Checking GID of KUBE_DATA_VOLUME"
echo "KUBE_JOB_FSGID: ${KUBE_JOB_FSGID}"
if [[ "${KUBE_JOB_FSGID}" == "" || "${DATA_VOLUME_GID}" == "0" ]]; then
  log "ERROR: Failed to get GID of KUBE_DATA_VOLUME OR GID was 0"
  exit 1
fi
KUBE_JOB_FS_GROUPNAME=$(getent group ${KUBE_JOB_FSGID} | cut -d: -f1)
echo "KUBE_JOB_FS_GROUPNAME: ${KUBE_JOB_FS_GROUPNAME}"

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
  name: ssh-${KUBE_JOB_NAME}
  labels:
    app: ${KUBE_JOB_NAME}
spec:
  type: ClusterIP
  ports:
  - name: sshd
    port: 22
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
  - name: dshm
    emptyDir:
      medium: Memory
      sizeLimit: 32Gi
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
    # command: ["/bin/bash"]
    # args: ["-c","${KUBE_SCRIPT}"]
    command: ["/usr/sbin/sshd","-e","-D"]
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
    volumeMounts:
    - name: apps
      mountPath: /apps
    - name: data
      mountPath: "${KUBE_DATA_VOLUME}"
    - name: home
      mountPath: "${USER_HOME}"
    - name: dshm
      mountPath: /dev/shm
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
  POD_STATUS=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep State: |awk '{print $2}')
  if [[ ${POD_STATUS} == 'Terminated' ]]; then
    POD_EXIT_CODE=$(kubectl describe pods -n ${KUBE_NAMESPACE} ${KUBE_JOB_NAME} |grep 'Exit Code:' |awk '{print $3}')
    log "Container terminated with exit code '${POD_EXIT_CODE}'"
    exit ${POD_EXIT_CODE}
  fi
  sleep ${KUBE_POD_MONITOR_INTERVAL}
done

exit 0
