#!/bin/bash

# Activate the Conda environment
myenv="pb-16s-nf_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || \
  ( echo "# the conda environment ${myenv} was not found on this machine" ;
    echo "# please read the top part of the script!" \
    && exit 1 )

# Run the provided command
exec "$@"
