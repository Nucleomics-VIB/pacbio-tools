#!/bin/bash

# script: dockerize_it.sh
# Aim: create a  docker image from the bash Kinnex_16S_decat_demux/ pipeline
#
# Stéphane Plaisance - VIB-Nucleomics Core - 2024-06-17 v1.0b
#
# visit our Git: https://github.com/Nucleomics-VIB

# NOTES:
# created after seing your demo this morning
# out of my memory and with probably several eerrors

# Set the name of the Docker image
DOCKER_IMAGE_NAME="kinnex_16s_tools"
DOCKER_IMAGE_TAG="1.0.0"

# Check if the Conda environment YAML file exists
if [ ! -f "environment.yml" ]; then
    echo "Error: environment.yml file not found in the current directory."
    exit 1
fi

# Create the Dockerfile
cat << EOF > Dockerfile
FROM continuumio/miniconda3:24.4.0-0

# Set the user and group IDs
#ARG DEFAULT_USER=$(id -u)
#ARG DEFAULT_GROUP=$(id -g)

# Create the app directory and set the ownership
#RUN mkdir -p /app && chown -R ${DEFAULT_USER}:${DEFAULT_GROUP} /app

# Set the user and group IDs
#USER ${DEFAULT_USER}:${DEFAULT_GROUP}

# this seems to work
RUN apt-get update -y && \
    apt-get install -y less curl tree pigz && \
    apt-get clean

# Set the working directory
WORKDIR /app

# Override default shell and use bash
SHELL ["/bin/bash", "--login", "-c"]

# Copy the environment YAML file
COPY conda_env_setup.yaml environment.yml

# copy the pipeline and deps
COPY scripts /app/scripts
COPY barcode_files /app/barcode_files
COPY info /app/info

# Activate the Conda environment and install dependencies
RUN conda init && \
    conda update -c defaults -n base conda && \
    conda activate base && \
    conda env create --file environment.yml

# Add the alias to the .bashrc file
RUN echo "alias ll='ls -lah'" >> ~/.bashrc

# Copy the wrapper script and make it executable
COPY run_in_env.sh .
COPY create_archive.sh .
RUN chmod +x run_in_env.sh
RUN chmod +x create_archive.sh
RUN chmod +x scripts/*

ENTRYPOINT ["./run_in_env.sh"]

EOF

# Build the Docker image
echo "Building Docker image: $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"
docker build -t $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG .

# Run the Docker image
echo "Running Docker image interactively: $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG"
docker run -it --rm -v $PWD:$PWD $DOCKER_IMAGE_NAME:$DOCKER_IMAGE_TAG /bin/bash
