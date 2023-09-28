#!/bin/bash


function get_node_cpu_limit() {
  NODE_NAME=$1
  FRACTION_OF_TOTAL=$2

  # Get Total CPUs From slurm.conf, if we don't find one, set it to 0
  NODE_DEF=$(grep "^NodeName=$NODE_NAME" /etc/slurm/slurm.conf)
  TOTAL_CPU=$(echo $NODE_DEF | grep -o 'CPUs=[0-9]*' | awk -F'=' '{print $2}')
  [[ -z $TOTAL_CPU ]] && TOTAL_CPU=0

  # Calculate desired fraction of total for limit, and round to int
  CPU_LIMIT=$(echo "$TOTAL_CPU * $FRACTION_OF_TOTAL" |bc)
  printf "%.0f" $CPU_LIMIT
}

function get_node_mem_limit() {
  NODE_NAME=$1
  FRACTION_OF_TOTAL=$2

  # Get Total Memory From slurm.conf, if we don't find one, set it to 0
  NODE_DEF=$(grep "^NodeName=$NODE_NAME" /etc/slurm/slurm.conf)
  TOTAL_MEM=$(echo $NODE_DEF | grep -o 'RealMemory=[0-9]*' | awk -F'=' '{print $2}')
  [[ -z $TOTAL_MEM ]] && TOTAL_MEM=0

  # Calculate desired fraction of total for limit, and round to int
  MEM_LIMIT=$(echo "$TOTAL_MEM * $FRACTION_OF_TOTAL" |bc)
  printf "%.0f" $MEM_LIMIT
}

KUBE_NODE="nvidia-node01"
KUBE_PERCENT_OF_NODE_LIMIT=0.5

KUBE_CPU_LIMIT=$(get_node_cpu_limit $KUBE_NODE $KUBE_PERCENT_OF_NODE_LIMIT)
KUBE_MEM_LIMIT=$(get_node_mem_limit $KUBE_NODE $KUBE_PERCENT_OF_NODE_LIMIT)
echo $KUBE_CPU_LIMIT
echo $KUBE_MEM_LIMIT