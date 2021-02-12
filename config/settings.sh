#!/bin/bash
# Global Settings for Shell Scripts

# Build Settings
DOCKER_REGISTRY=registry.local:31500

# Wrapper Settings
KUBE_INIT_TIMEOUT=600
KUBE_POD_MONITOR_INTERVAL=10
KUBE_NAMESPACE=slurm
KUBE_CLUSTER_DNS=nvidia-pod
KUBECONFIG=~/.kube/config