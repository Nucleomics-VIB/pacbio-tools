#!/bin/bash

# script: install_conda_env.sh
# requires conda installed and running

# This script creates a conda env with tools required for the pipeline
# it then manually installs yq v4.44.1 on the new conda environment
# due to conda-forge only supporting v3.4.1, which does not support nice parsing of yaml multiline files
# SP@NC 2024-06-14

# Check if the environment exists
if ! conda env list | grep -q "Kinnex_16S_decat_demux_env"; then
  # Create the conda environment if it does not exist
  conda env create -f conda_env_setup.yaml || (
    echo "# Failed to create the conda environment ${myenv}"
    echo "# Please check the conda_env_setup.yaml file and try again."
    exit 1
  )
fi

# Activate the conda environment
myenv="Kinnex_16S_decat_demux_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || (
  echo "# the conda environment ${myenv} was not found on this machine"
  echo "# please read the top part of the script!"
  exit 1
)

# Add yq to the conda env from the binary build
# yq version 4 is not available on conda-forge
# Current latest version and platform
vers="4.44.1"
kernel="linux"
arch="amd64"

# Download and extract yq
curl -O -L "https://github.com/mikefarah/yq/releases/download/v${vers}/yq_${kernel}_${arch}.tar.gz"
tar -xzvf "yq_${kernel}_${arch}.tar.gz"

# Cleanup
mv "yq_${kernel}_${arch}" "$CONDA_PREFIX/bin/yq"
mv yq.1 "$CONDA_PREFIX/man/man1/"
rm install-man-page.sh

# Test newly installed yq
yq --version && rm "yq_${kernel}_${arch}.tar.gz"
