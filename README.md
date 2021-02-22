# kube-slurm

Tools for managing Kubernetes resources as slurm jobs.

## TODO

- [ ] Finish writing README, it is incomplete
- [ ] Create additional job examples and containers

## Why?

These tools are designed for use with an Nvidia DGX Pod, deployed with Slurm and Kubernetes. Specifially, these wrappers allow slurm to be used by users to create pods (and other resources) in kubernetes and provides a better way to control time-sharing.

The default Kubernetes scheduler does not implement concepts like slurm's "fair-share" to help with allocating resources to users. A hybrid approach can maximize the strengths of both scheduling systems. 

## Getting Started

### Requirements

#### Assumptions

* Users should be able to read/execute the SBATCH templates on Login nodes
* Users must exist on all compute/gpu nodes, BUT they MUST NOT be able to login/ssh to them
* Shared file storage is present on all nodes (NFS, etc.)
* kubectl is installed on all nodes
* A KUBECONFIG file with permissions to the cluster is available on all compute nodes

## Tool Inventory

Directory | Description
--------- | -----------
config | Common/Global configuration and settings
containers | Dockerfiles and other resources to build the supported containers
templates | Slurm SBATCH template scripts (Modify these to get started)
tests | Simple scripts to test the wrappers without Slurm
wrappers | Kubernetes wrappers (these are invoked by the Slurm SBATCH scripts)