#!/bin/bash
set -e

if [ "$1" = "slurmdbd" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    [[ -f /etc/munge/munge.key ]] || mungekey --create && chown munge /etc/munge/munge.key
    gosu munge /usr/sbin/munged

    echo "---> Starting the Slurm Database Daemon (slurmdbd) ..."
    cp -f /etc/slurm/slurm.conf.injected /etc/slurm/slurm.conf && chmod 600 /etc/slurm/slurm.conf
    cp -f /etc/slurm/slurmdbd.conf.injected /etc/slurm/slurmdbd.conf && chmod 600 /etc/slurm/slurmdbd.conf
    chown -R slurm /etc/slurm/*.conf
    chown -R slurm /var/log/slurm*
    {
        . /etc/slurm/slurmdbd.conf
        until echo "SELECT 1" | mysql -h $StorageHost -u$StorageUser -p$StoragePass 2>&1 > /dev/null
        do
            echo "-- Waiting for database to become active ..."
            sleep 2
        done
    }
    echo "-- Database is now active ..."

    exec gosu slurm /usr/sbin/slurmdbd -Dvvv
fi

if [ "$1" = "slurmctld" ]
then
    echo "---> Starting the MUNGE Authentication service (munged) ..."
    gosu munge /usr/sbin/munged

    echo "---> Waiting for slurmdbd to become active before starting slurmctld ..."

    until 2>/dev/null >/dev/tcp/slurmdbd/6819
    do
        echo "-- slurmdbd is not available.  Sleeping ..."
        sleep 2
    done
    echo "-- slurmdbd is now active ..."

    echo "---> Starting the Slurm Controller Daemon (slurmctld) ..."
    cp -f /etc/slurm/slurm.conf.injected /etc/slurm/slurm.conf && chmod 600 /etc/slurm/slurm.conf
    cp -f /etc/slurm/slurmdbd.conf.injected /etc/slurm/slurmdbd.conf && chmod 600 /etc/slurm/slurmdbd.conf
    chown -R slurm /etc/slurm/*.conf
    chown -R slurm /var/log/slurm*
    chown -R slurm /var/lib/slurm*
    chown -R slurm /var/spool/slurm*
    exec gosu slurm /usr/sbin/slurmctld -Dvvv
fi

if [ "$1" = "slurmd" ]
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
    exec /usr/sbin/slurmd -Dvvv
fi

exec "$@"
