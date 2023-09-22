# kube-slurm container images
These are container image builds for the various containers required by kube-slurm

## Usage
Each of these images should be built and pushed to a registry.

NOTE: the slurm-cluster image includes a build script to make building it easier. It requires certain parameters be built into the container and can be specified in the .env file.

## Container Idex
| Image/Directory   | Description                                                                                          |
| ----------------- | ---------------------------------------------------------------------------------------------------- |
| lambda-base-image | Lambda Lab's base image for the Lambda Stack. Can be used on Lambda Nodes                            |
| lambda-openmpi    | Image based on Lambda image, uased to run multi-node GPU jobs with OpenMPI                           |
| slurm-cluster     | Single Image used for slurm cluster componets: slurmctld and slurmdbd. Can also run slurmd if needed |
| slurm-job-test    | A simple image to test job execution                                                                 |
| slurm-jupyter-tf  | Image for running Jypyter notebooks with Tensorflow (may be broken)                                  |