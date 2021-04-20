FROM nvcr.io/nvidia/tensorflow:20.12-tf1-py3

# Update & Install packages
RUN apt-get update -y && \
    apt-get install -y bash git vim

# Copy local lmod
COPY /usr/local/bin/lmod /usr/local/bin/lmod
RUN chmod +x /usr/local/bin/lmod

# Set Envs
ENV KUBE_SCRIPT=${KUBE_SCRIPT}

# Run Requested Script
ENTRYPOINT ["/bin/bash"]
CMD ["-c", "${KUBE_SCRIPT}"]