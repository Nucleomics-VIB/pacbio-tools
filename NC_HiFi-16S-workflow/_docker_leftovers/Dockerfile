FROM continuumio/miniconda3:24.4.0-0

# this seems to work
RUN apt-get update -y &&     apt-get install -y less curl tree pigz &&     apt-get clean

# Set the working directory
WORKDIR /app

# Override default shell and use bash
SHELL ["/bin/bash", "--login", "-c"]

# Copy the environment YAML file
COPY environment.yml environment.yml

# copy the pipeline and deps
COPY scripts /app/scripts
COPY info /app/info

# Activate the Conda environment and install dependencies
RUN conda init &&     conda update -c defaults -n base conda &&     conda activate base &&     conda env create --file environment.yml

# import nextflow from repo
# https://github.com/PacificBiosciences/HiFi-16S-workflow?tab=readme-ov-file#installation-and-usage)
RUN conda init &&   conda activate pb-16s-nf_env &&   git clone https://github.com/PacificBiosciences/pb-16S-nf.git &&   cd pb-16S-nf &&   nextflow run main.nf --download_db

# Add the alias to the .bashrc file
RUN echo "alias ll='ls -lah'" >> ~/.bashrc

# Copy the wrapper script and make it executable
COPY run_in_env.sh .
COPY create_archive.sh .
RUN chmod +x run_in_env.sh
RUN chmod +x create_archive.sh
RUN chmod +x scripts/*

# overwrite git version with NC modified files
COPY updates/nextflow.config pb-16S-nf/nextflow.config
COPY updates/extra.config pb-16S-nf/extra.config

ENTRYPOINT ["./run_in_env.sh"]

