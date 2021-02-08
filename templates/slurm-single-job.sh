[dgxadmin@erisxdl1 templates]$ cat slurm-single-job.sh
#!/bin/bash
#SBATCH --job-name=slurm-single-job
#SBATCH --output=/tmp/slurm-single-job.log
#SBATCH --nodelist=dgx-1
#SBATCH --ntasks=1
#SBATCH --mem-per-cpu=100
#SBATCH --gpus=2

# Set Docker Image
export KUBE_IMAGE=hello-world

srun hostname
srun date
srun ../wrappers/kube-slurm-image-job.sh