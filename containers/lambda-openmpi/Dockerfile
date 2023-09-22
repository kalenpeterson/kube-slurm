FROM docker.io/kalenpeterson/lambda-base-image:20230706-v1

# Install APT Requirements
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes \
    iputils-ping net-tools iproute2 dnsutils curl vim-tiny wget openssh-client openssh-server netcat \
    libipathverbs1 librdmacm1 libibverbs1 libmthca1 libopenmpi-dev openmpi-bin openmpi-common openmpi-doc \
    libmlx4-1 rdmacm-utils ibverbs-utils infiniband-diags ibutils perftest udev&& \
    rm -rf /var/lib/apt/lists/*

# Install Python Requirements
# hostlist isused to expand slurm node lists
#  https://www.nsc.liu.se/~kent/python-hostlist/
RUN pip install --upgrade pip && \
    pip install python-hostlist

# Install NCCL Tests
RUN mkdir -p /nccl && \
    cd /nccl && \
    git clone https://github.com/NVIDIA/nccl-tests.git && \
    cd nccl-tests && \
    make MPI=1 CUDA_HOME=/usr NCCL_HOME=/usr MPI_HOME=/usr/lib/x86_64-linux-gnu/openmpi/

# Setup Common User SSH Keys
RUN mkdir -p /var/run/sshd && \
    mkdir -p /templates/.ssh && \
    ssh-keygen -t rsa -b 2048 -f /templates/.ssh/id_rsa -q -N "" && \
    cat /templates/.ssh/id_rsa.pub > /templates/.ssh/authorized_keys && \
    chmod 600 /templates/.ssh/authorized_keys

# Copy in SSH Config
COPY ssh_config /etc/ssh/ssh_config
COPY sshd_config /etc/ssh/sshd_config

RUN chmod 644 /etc/ssh/ssh_config && \
    chmod 644 /etc/ssh/sshd_config

# Copy in the Entrypoint
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 2222
