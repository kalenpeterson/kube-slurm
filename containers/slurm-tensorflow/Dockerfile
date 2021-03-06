# https://ngc.nvidia.com/catalog/containers/nvidia:tensorflow
FROM nvcr.io/nvidia/tensorflow:20.12-tf1-py3

# Install some extra packages to ease development
RUN apt-get update && \
    apt-get install -y screen unzip git vim htop font-manager && \
    rm -rf /var/lib/apt/*

# Upgrade to Jupyterlab 3
RUN  source "$NVM_DIR/nvm.sh" && \
     pip install jupyterlab

# Installing a Jupyter labextension requires npm and Node.
# To enable the built-in Node environment we must source the nvm.sh script.
# Install the NVIDIA Jupyter Dashboard
RUN  source "$NVM_DIR/nvm.sh" && \
     pip install jupyterlab-nvdashboard==0.4.0 && \
     jupyter labextension install jupyterlab-nvdashboard

# Install ipyvolume for clean HTML5 visualizations
RUN source "$NVM_DIR/nvm.sh" && \
    pip install ipyvolume==0.5.2 && \
    jupyter labextension install ipyvolume

# Install graphviz for clean graph/node/edge rendering
RUN source "$NVM_DIR/nvm.sh" && \
    apt-get update && \
    apt-get install -s graphviz=2.42.2-3build2 && \
    pip install graphviz==0.16 && \
    rm -rf /var/lib/apt/*

# Get latest pip updates
RUN  pip install --upgrade pip

# Download DeepLearningExamples
#RUN cd /workspace && git clone https://github.com/NVIDIA/DeepLearningExamples.git

# Expose Jupyter & Tensorboard
EXPOSE 8888
EXPOSE 6006

# /workspace contains NVIDIA tutorials and example code
WORKDIR /workspace

# Install some extra packages to ease development
RUN apt-get update && \
    apt-get install -y sudo && \
    rm -rf /var/lib/apt/*

# Copy in start.sh to handle custom UID
COPY start.sh /root/start.sh

# Chmod it
RUN chmod +x /root/start.sh

# Set Envs
ENV NB_TOKEN=${NB_TOKEN}
ENV NB_USER=${NB_USER}
ENV NB_UID=${NB_UID}
ENV NB_GROUP=${NB_GROUP}
ENV NB_GID=${NB_GID}

# Start Jupyter up by default rather than a shell
ENTRYPOINT ["/bin/sh"]
CMD ["-c", "/root/start.sh jupyter lab  --notebook-dir=/workspace --ip=0.0.0.0 --no-browser --port=8888 --NotebookApp.token=${NB_TOKEN} --NotebookApp.password='' --NotebookApp.allow_origin='*' --NotebookApp.base_url=${NB_PREFIX}"]
