FROM erisxdl.partners.org/library/lambda-openmpi:20230706-v1

RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install --yes \
    iputils-ping net-tools iproute2 dnsutils curl vim-tiny wget openssh-client openssh-server netcat && \
    rm -rf /var/lib/apt/lists/*

RUN ssh-keygen -t rsa -b 2048 -f ~/.ssh/id_rsa -q -N "" && \
    cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys

RUN echo "Host *" > ~/.ssh/config && \
    echo "    StrictHostKeyChecking no" >> ~/.ssh//config && \
    chmod 600 ~/.ssh/config

RUN mkdir -p /var/run/sshd

RUN apt-get update -y && \
    apt-get install --yes libipathverbs1 librdmacm1 libibverbs1 libmthca1 libopenmpi-dev openmpi-bin openmpi-common openmpi-doc libmlx4-1 rdmacm-utils ibverbs-utils infiniband-diags ibutils perftest

EXPOSE 22

CMD ["/usr/sbin/sshd","-D"]