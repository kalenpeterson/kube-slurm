#!/bin/bash
#SBATCH --job-name=SimpleImageRun
#SBATCH --output=SimpleImageRun.log
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=<email_address>
#SBATCH --nodes=1              # Number of nodes
#SBATCH --ntasks=1             # Number of MPI ranks
#SBATCH --ntasks-per-node=1    # Number of MPI ranks per node
#SBATCH --ntasks-per-socket=1  # Number of tasks per processor socket on the node
#SBATCH --cpus-per-task=1      # Number of OpenMP threads for each MPI process/rank
#SBATCH --mem-per-cpu=2000mb   # Per processor memory request

export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK

srun --mpi=pmi_v1 /path/to/app/lmp_gator2 < in.Cu.v.24nm.eq_xrd

date
