#!/bin/bash
## Manage Jupyter Job Pods from Slurm
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

# Set Job Details
KUBE_JOB_NAME=slurm-job-${SLURM_JOB_ID}
KUBE_JOB_UID=$(id -u)
KUBE_JOB_GID=$(id -g)
KUBE_JOB_USER=$(id -un)
KUBE_JOB_GROUP=$(id -gn)
KUBE_NODE=${SLURMD_NODENAME}
KUBE_GPU_COUNT=${SLURM_GPUS}
KUBE_INIT_TIMEOUT=${KUBE_INIT_TIMEOUT:=600}
KUBE_POD_MONITOR_INTERVAL=${KUBE_POD_MONITOR_INTERVAL:=10}
KUBE_NAMESPACE=${KUBE_NAMESPACE:=slurm}
KUBE_CLUSTER_DNS=${KUBE_CLUSTER_DNS:=nvidia-pod}
KUBE_INGRESS_PREFIX="/jupyter"
KUBE_TARGET_PORT=${KUBE_TARGET_PORT:=8888}
USER_HOME=${HOME}
KUBE_DATA_VOLUME=${KUBE_DATA_VOLUME}

# Setup Kubeconfig
export KUBECONFIG=${KUBECONFIG:=~/.kube/config}

# Print Kube ENV Vars
echo
echo "Kube ENV Vars:"
echo "KUBE_JOB_NAME: ${KUBE_JOB_NAME}"
echo "KUBE_JOB_UID: ${KUBE_JOB_UID}"
echo "KUBE_JOB_GID: ${KUBE_JOB_GID}"
echo "KUBE_IMAGE: ${KUBE_IMAGE}"
echo "KUBE_DATA_VOLUME: ${KUBE_DATA_VOLUME}"
echo "KUBE_TARGET_PORT: ${KUBE_TARGET_PORT}"
echo "KUBE_NODE: ${KUBE_NODE}"
echo "KUBE_GPU_COUNT: ${KUBE_GPU_COUNT}"
echo "KUBE_INIT_TIMEOUT: ${KUBE_INIT_TIMEOUT}"
echo "KUBE_POD_MONITOR_INTERVAL: ${KUBE_POD_MONITOR_INTERVAL}"
echo "KUBE_NAMESPACE: ${KUBE_NAMESPACE}"
echo "KUBE_CLUSTER_DNS: ${KUBE_CLUSTER_DNS}"
echo "KUBE_INGRESS_PREFIX: ${KUBE_INGRESS_PREFIX}"
echo "KUBE_TARGET_PORT: ${KUBE_TARGET_PORT}"
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

# Collect the Pod Error
function get_pod_error () {
  NAMESPACE=$1
  POD=$2
  log "Collecting POD Events..."
  kubectl describe pod -n ${NAMESPACE} ${POD} |grep -A20 Events
  log "Collecting POD Logs"
  kubectl logs -n ${NAMESPACE} ${POD}
}

## Check Data Volume and get it's GID
log "Checking GID of KUBE_DATA_VOLUME"
KUBE_JOB_FSGID=$(getfacl -nat "${KUBE_DATA_VOLUME}" 2>/dev/null |grep ^GROUP |awk '{print $2}')
echo "KUBE_JOB_FSGID: ${KUBE_JOB_FSGID}"
if [[ "${KUBE_JOB_FSGID}" == "" || "${KUBE_DATA_VOLUME}" == "0" ]]; then
  log "ERROR: Failed to get GID of KUBE_DATA_VOLUME OR GID was 0"
  exit 1
fi

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
  type: ClusterIP
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
JUPYTER_URL="https://${KUBE_CLUSTER_DNS}${KUBE_INGRESS_PREFIX}/${KUBE_JOB_NAME}?token=${JUPYTER_TOKEN}"
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
  securityContext:
    runAsUser: ${KUBE_JOB_UID}
    runAsGroup: ${KUBE_JOB_FSGID}
  volumes:
  - name: data
    hostPath:
      type: Directory
      path: "${KUBE_DATA_VOLUME}"
  - name: home
    hostPath:
      type: Directory
      path: "${USER_HOME}"
  - name: etc
    hostPath:
      path: /etc
  restartPolicy: Never
  containers:
  - name: ${KUBE_JOB_NAME}
    image: ${KUBE_IMAGE}
    command: ["/bin/sh"]
    args:
      - "-c"
      #- "sleep infinity"
      - "jupyter lab  --notebook-dir=/work --ip=0.0.0.0 --no-browser --port=8888 --NotebookApp.token=${JUPYTER_TOKEN} --NotebookApp.password='' --NotebookApp.allow_origin='*' --NotebookApp.base_url=${KUBE_INGRESS_PREFIX}/${KUBE_JOB_NAME}"
    volumeMounts:
    - name: data
      mountPath: /work/data
    - name: home
      mountPath: /work/home
    - name: home
      mountPath: /home/${KUBE_JOB_USER}
    - mountPath: /etc/passwd
      name: etc
      subPath: passwd
    - mountPath: /etc/group
      name: etc
      subPath: group
    env:
    - name: HOME
      value: "/home/${KUBE_JOB_USER}"
    ports:
    - name: jupyter-http
      containerPort: ${KUBE_TARGET_PORT}
      protocol: TCP
    ${KUBE_GPU_LIMIT}
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
