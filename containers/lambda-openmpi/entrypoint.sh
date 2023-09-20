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
    groupadd -g ${KUBE_JOB_FSGID} ${KUBE_JOB_FS_GROUPNAME}
    useradd -u ${KUBE_JOB_UID} -g ${KUBE_JOB_FSGID} ${KUBE_JOB_USERNAME} -M -d "${USER_HOME}" -s /bin/bash
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
    OPENMPI_NODE_LIST_CSV=$(hostlist --expand -s , ${SLURM_JOB_NODELIST})
    OPENMPI_TOTAL_GPUS=$(($SLURM_JOB_NUM_NODES * $SLURM_GPUS_PER_NODE))
    OPENPUT_HOST_STRING=''
    echo "Job will run with '${SLURM_JOB_NUM_NODES}' nodes and '${SLURM_GPUS_PER_NODE}' GPUs per node"
    echo "Total GPU count is '${OPENMPI_TOTAL_GPUS}'"
    echo "OPENMPI_NODE_LIST_CSV: ${OPENMPI_NODE_LIST_CSV}"
    echo "OPENMPI_CONNECTION_TIMEOUT: ${OPENMPI_CONNECTION_TIMEOUT}"

    IFS=',' read -ra WORKER_PODS <<< "$OPENMPI_NODE_LIST_CSV"
    for WORKER_POD in "${WORKER_PODS[@]}"; do
        WORKER_HOSTNAME="slurm-job-${SLURM_JOB_ID}-${WORKER_POD}"
        OPENPUT_HOST_STRING+="${WORKER_HOSTNAME}:${SLURM_GPUS_PER_NODE},"

        COUNT=0
        while [[ $COUNT -lt $OPENMPI_CONNECTION_TIMEOUT ]]
        do
            2>/dev/null >/dev/tcp/${WORKER_HOSTNAME}/2222 && CONNECTED=1 || CONNECTED=0
            if [[ $CONNECTED -eq 1 ]]; then
                break
            else
                echo "-- Worker ${WORKER_HOSTNAME} is not ready yet.  Retrying (${COUNT}/${OPENMPI_CONNECTION_TIMEOUT})"
                COUNT=$(($COUNTER + 1))
                sleep 1
            fi
        done

        if [[ $COUNT -ge $OPENMPI_CONNECTION_TIMEOUT ]]; then
            echo "-- Timed-out waiting for Worker to be ready"
            exit 2
        fi

        echo "-- Worker ${WORKER_HOSTNAME} is ready."
    done
    OPENPUT_HOST_STRING=${OPENPUT_HOST_STRING::-1}

    echo "-- All workers are ready starting mpirun ..."
    echo "mpirun command: mpirun -np ${OPENMPI_TOTAL_GPUS} --host ${OPENPUT_HOST_STRING} -mca btl tcp,self  -x NCCL_DEBUG=INFO -x NCCL_SOCKET_IFNAME=eth0 -x NCCL_IB_HCA=mlx5_0,mlx5_2,mlx5_4,mlx5_6,mlx5_8,mlx5_10,mlx5_12,mlx5_14,mlx5_16 ${KUBE_SCRIPT} ${KUBE_SCRIPT_VARS}"
    
    exec mpirun -np ${OPENMPI_TOTAL_GPUS} \
        -mca plm_rsh_args "-p 2222" \
        --host ${OPENPUT_HOST_STRING} \
        -mca btl tcp,self  -x NCCL_DEBUG=INFO -x NCCL_SOCKET_IFNAME=eth0 \
        -x NCCL_IB_HCA=mlx5_0,mlx5_2,mlx5_4,mlx5_6,mlx5_8,mlx5_10,mlx5_12,mlx5_14,mlx5_16 \
        "${KUBE_SCRIPT}" ${KUBE_SCRIPT_VARS}
    
    exit 0
fi

## slurmd Entrypoint ##
if [ "$1" = "worker" ]
then
    echo "---> Starting the OpenMPI WORKER Entrypoint ..."

    echo "---> Starting sshd ..."
    /usr/sbin/sshd -e || exit 1

    echo "---> Waiting for Controller to become ready..."
    OPENMPI_CONTROLLER_HOSTNAME="slurm-job-${SLURM_JOB_ID}-${OPENMPI_CONTROLLER}"
    until 2>/dev/null >/dev/tcp/${OPENMPI_CONTROLLER_HOSTNAME}/2222
    do
        echo "-- Controller ${OPENMPI_CONTROLLER_HOSTNAME} is not available.  Retrying ..."
        sleep 2
    done
    echo "-- Controller ${OPENMPI_CONTROLLER_HOSTNAME} is ready. Sleeping until controller shuts down..."

    while 2>/dev/null >/dev/tcp/${OPENMPI_CONTROLLER_HOSTNAME}/2222
    do
        sleep 5
    done
    echo "-- Controller ${OPENMPI_CONTROLLER_HOSTNAME} has become unreachable, Shutting down worker ..."
    exit 0
fi

# Disable fall-through exec
#exec "$@"
