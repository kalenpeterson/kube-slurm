#!/bin/bash
## Manage Jupyter Notebook Pods via Slurm

# Job Details
JOB_NAME=slurm-job-1234-jupyter
JOB_UID=1001
JOB_GID=1001
IMAGE=slurm-tensorflow:latest
PORT=8888
NODE=nvidia-mgmt01
GPU_COUNT=4
TIMEOUT=600

# Globals
CLUSTER_DNS=nvidia-pod
NAMESPACE=slurm

## Manage Cleanup for Job Signals
WATCH_LOGS=true
function cleanup () {
  echo "Cleaning up resources"
  WATCH_LOGS=false
  kubectl get pod ${JOB_NAME} -n ${NAMESPACE} 2>/dev/null && kubectl delete pod ${JOB_NAME} -n ${NAMESPACE}
  kubectl get service ${JOB_NAME} -n ${NAMESPACE} 2>/dev/null && kubectl delete service ${JOB_NAME} -n ${NAMESPACE}
}
trap cleanup EXIT # Normal Exit
trap cleanup SIGTERM # Termination from SLurm

## Ensure Namespace Exists
kubectl get namespace ${NAMESPACE} 2>/dev/null || kubectl create namespace ${NAMESPACE}

## Create Service
echo "Creating Notebook NodePort Service"

cat <<EOF | kubectl create -n ${NAMESPACE} -f -
---
apiVersion: v1
kind: Service
metadata:
  name: ${JOB_NAME}
  labels:
    app: ${JOB_NAME}
spec:
  type: NodePort
  ports:
  - name: ${JOB_NAME}
    port: ${PORT}
    targetPort: ${PORT}
    protocol: TCP
  selector:
    app: ${JOB_NAME}
EOF

## Generate Random Login Token
TOKEN=$(openssl rand -base64 24)

## Generate Notebook URL
NODE_PORT=$(kubectl describe service ${JOB_NAME} -n ${NAMESPACE} |grep NodePort: |awk '{print $3}' |awk -F/ '{print $1}')
JUPYTER_URL="http://${CLUSTER_DNS}:${NODE_PORT}?token=${TOKEN}"
echo "########################################################"
echo "Your Jupyter Notebook URL will be: ${JUPYTER_URL}"
echo "########################################################"

## Start Kube Job
#kubectl run ${JOB_NAME} --rm --tty --stdin --attach --restart=Never -n ${NAMESPACE} \
#kubectl run ${JOB_NAME} --restart=Never -n ${NAMESPACE} \
  #--image=${IMAGE} --labels="app=${JOB_NAME}" --port=${PORT} \
  #--overrides='{ "apiVersion": "v1", "spec": { "template": { "spec": { "nodeSelector": { "kubernetes.io/hostname": "${NODE}" } } } } }' \
  #--limits=nvidia.com/gpu=${GPU_COUNT}

## Create Pod
echo "Creating Notebook Pod"
cat <<EOF | kubectl create -n ${NAMESPACE} -f -
---
apiVersion: v1
kind: Pod
metadata:
  name: ${JOB_NAME}
  labels:
    app: ${JOB_NAME}
spec:
  restartPolicy: Never
  containers:
  - name: ${JOB_NAME}
    image: ${IMAGE}
    env:
    - name: NB_TOKEN
      value: ${TOKEN}
    ports:
    - name: jupyter-http
      containerPort: 8888
      protocol: TCP
  nodeSelector:
    kubernetes.io/hostname: ${NODE}
EOF


## Wait for Container to start
echo "Waiting ${TIMEOUT} seconds for container to be ready"
kubectl wait --for=condition=ContainersReady --timeout=${TIMEOUT}s -n ${NAMESPACE} pods ${JOB_NAME} || exit 2

## Watch Logs
echo "Container Ready, following logs (updates every 10s)"
while ${WATCH_LOGS}
do
  kubectl logs --since=10s -n ${NAMESPACE} ${JOB_NAME} || exit 3
  sleep 10
done

exit 0
