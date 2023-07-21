#!/bin/bash
# OpenMPI Multicluster Pod Entrypoint
#  This is a common entrypoint so that a single image can be used for all componets
#  of an OpenMPI Multinode Job
# Valid entrypoint args:
#  - init
#  - controller
#  - worker
set -e

## init Entrypoint ##
if [ "$1" = "init" ]
then
    echo "---> Starting the OpenMPI INIT Entrypoint ..."
    
    echo "Setting-up /currentuser directory"
    chmod 755 /currentuser
    mkdir -p /currentuser/user
    chmod 700 /currentuser/user
    cp -rp /templates/.ssh /currentuser/user/
    cp -rp /etc/ssh/ssh_host_* /currentuser/user/.ssh/
    chown -R ${KUBE_JOB_UID}:${KUBE_JOB_FSGID} /currentuser/user

    echo "Adding current User and Group"
    groupadd -g ${KUBE_JOB_FSGID} mygroup
    useradd -u ${KUBE_JOB_UID} -g ${KUBE_JOB_FSGID} user -M -d "${USER_HOME}" -s /bin/bash
    cp -p /etc/passwd /currentuser/passwd
    cp -p /etc/group /currentuser/group

    echo "Init Complete"
    exit 0
fi

## slurmdctld Entrypoint ##
if [ "$1" = "controller" ]
then
    echo "---> Starting the OpenMPI CONTROLLER Entrypoint ..."

    echo "---> Starting sshd ..."
    /usr/sbin/sshd -e || exit 1

    echo "---> Waiting for all nodes to become active before starting OpenMPI Job..."
    WORKER_PODS_LIST="$2"
    IFS=',' read -ra WORKER_PODS <<< "$WORKER_PODS_LIST"
    for WORKER_POD in "${WORKER_PODS[@]}"; do
        until 2>/dev/null >/dev/tcp/${WORKER_POD}/22
        do
            echo "-- Worker ${WORKER_POD} is not available.  Retrying ..."
            sleep 2
        done
        echo "-- Worker ${WORKER_POD} is ready."
    done
    
    echo "-- All workers are ready starting mpirun ..."

    exec mpirun -np 32 \
        --host 192.168.1.31:8,192.168.1.32:8,192.168.1.33:8,192.168.1.34:8 \
        -mca btl tcp,self  -x NCCL_DEBUG=INFO -x NCCL_SOCKET_IFNAME=vlan2100 \
        -x NCCL_IB_HCA=mlx5_0,mlx5_2,mlx5_4,mlx5_6,mlx5_8,mlx5_10,mlx5_12,mlx5_14,mlx5_16 \
        "${KUBE_SCRIPT}" ${KUBE_SCRIPT_VARS} \
        -b 8 -e 4G -f 2 -g 1  
    exit
fi

## slurmd Entrypoint ##
if [ "$1" = "worker" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged

    echo "---> Waiting for slurmctld to become active before starting slurmd..."

    until 2>/dev/null >/dev/tcp/slurmctld/6817
    do
        echo "-- slurmctld is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmctld is now active ..."

    echo "---> Starting the Slurm Node Daemon (slurmd) ..."
    cp -f /etc/slurm/slurm.conf.injected /etc/slurm/slurm.conf && chmod 600 /etc/slurm/slurm.conf
    cp -f /etc/slurm/slurmdbd.conf.injected /etc/slurm/slurmdbd.conf && chmod 600 /etc/slurm/slurmdbd.conf
    exec /usr/sbin/slurmd -Dv
fi

# Disable fall-through exec
#exec "$@"
