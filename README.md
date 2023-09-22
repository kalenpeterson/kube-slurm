# kube-slurm

Tools for managing Kubernetes resources as slurm jobs. Also, includes tools to deploy slurm on-top of Kubernetes.

## Overview

These tools are designed for use with Nvidia GPU nodes, deployed with Slurm and Kubernetes. Specifially, these wrappers allow slurm to be used by users to create pods (and other resources) in kubernetes and provides a better way to control time-sharing.

The default Kubernetes scheduler does not implement concepts like slurm's "fair-share" to help with allocating resources to users. A hybrid approach can maximize the strengths of both scheduling systems.

This project also includes tools to deploy a slurm cluster on-top of kubernetes.

## Getting Started

### Requirements and Assumptions
* A functional kubernetes cluster
* Worker nodes with Nvidia GPUs
* Users should be able to read/execute the SBATCH templates on Login nodes
* Users must exist on all compute/gpu nodes.
* Shared file storage is present on all nodes (NFS, etc.)
* kubectl is installed on all nodes
* A KUBECONFIG file with permissions to the cluster is available on all compute nodes

See the following project for playbooks to manage DGX/Lambda labs clusters.
* https://github.com/kalenpeterson/dgx-setup


### Installation
To start, you will need to build the required container images, and then deploy the slurm cluster.

* To build images see: [Container Images](containers/README.md)
* Next, to deploy slurm see: [Slurm Deployment](deployment/slurm/README.md)

### Usage
Once kube-slurm id deployed, you can test submitting jobs. The following related objects accomplish this.

#### [Wrappers](wrappers/README.md)
Wrappers are shell scripts that are executed as slurm jobs. These are predefined by administrators and act as a shim between slurm and kubernetes. They will create and manage the kubernetes resources required for the job based on the inputs to the slurm job.

#### [SBatch Templates](templates/README.md)
Tempalates are slurm SBatch files that call the wrappers with the required pre-defined variables to execute a kube-slurm job. This is what end users should be submitting to slurm.

#### [Tests](tests/README.md) 
Misc tests for wrapper/template development. Mainly used to test kubernets jobs outside of slurm.


## Related Repos
These are other Repos related to this project that contain their own documentation and tooling.
| Git Repository                                                    | Description                                            |
| ----------------------------------------------------------------- | ------------------------------------------------------ |
| [dgx-setup](https://github.com/kalenpeterson/dgx-setup)           | Tools for configuring Nvidia DGX and Lambda Labs nodes |
| [dgx-chargeback](https://github.com/kalenpeterson/dgx-chargeback) | Tools to manage GPU Chargeback of kube-slurm clusters  |


## Document Index
| Document                                       | Description                                                        | Version Info             |
| ---------------------------------------------- | ------------------------------------------------------------------ | ------------------------ |
| [Container Images](containers/README.md)       | Description of container image builds                              | Kalen Peterson, Sep 2023 |
| [Slurm Deployment](deployment/slurm/README.md) | Kube-Slurm cluster deployment guide                                | Kalen Peterson, Sep 2023 |
| [RDMA Deployment](deployment/rdma/README.md)   | RDMA Operator guide (for Multinode GPU Jobs)                       | Kalen Peterson, Sep 2023 |
| [SBatch Templates](templates/)                 | Slurm SBatch Template examples for submitting kube-slurm jobs      | Kalen Peterson, Sep 2023 |
| [Tests](tests/)                                | Various tests for this tool suite                                  | Kalen Peterson, Sep 2023 |
| [Wrappers](wrappers/)                          | kube-slurm job wrappers (primary interface between slurm and kube) | Kalen Peterson, Sep 2023 |


## References
| URL                        | Description         |
| -------------------------- | ------------------- |
| https://slurm.schedmd.com/ | Slurm Documentation |

