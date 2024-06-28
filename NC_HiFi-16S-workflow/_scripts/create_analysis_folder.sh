#!/bin/bash

# create HiFi-16s-nf analysis folder
# takes 2 optional arguments:
# -w, --workdir: Path to the folder to be created (default: $PWD)
# -o, --outfolder: Name of the folder to be created (default: HiFi-16s-nf_results)
#
# Stephane Plaisance (VIB-NC) 2024/06/27; v1.0

# Set default values for optional arguments
workdir="${PWD}"
outfolder="HiFi-16s-nf_results"

# Prompt the user for input and provide default values
read -p "Enter the path to the folder to be created (default: $workdir): " user_workdir
if [ -n "$user_workdir" ]; then
    workdir="$user_workdir"
fi

read -p "Enter the name of the folder to be created (default: $outfolder): " user_outfolder
if [ -n "$user_outfolder" ]; then
    outfolder="$user_outfolder"
fi

# Validate the inputs
if [ -z "$workdir" ] || [ -z "$outfolder" ]; then
    echo "Error: Both the path to the folder and the folder name are required."
    exit 1
fi

if [ -d "$workdir/$outfolder" ]; then
    echo "Error: The folder '$workdir/$outfolder' already exists."
    exit 1
fi

mkdir -p "$workdir/$outfolder"
cp "_config.yaml" "$workdir/$outfolder/config.yaml"

# Replace placeholders in config.yaml
sed -i "s|<TOOLDIR>|$PWD|g" "$workdir/$outfolder/config.yaml"
sed -i "s|<OUTFOLDER>|$workdir/$outfolder|g" "$workdir/$outfolder/config.yaml"

ln -s "$PWD/run_pb-16s-nf-local.sh" "$workdir/$outfolder/"

cd "$workdir/$outfolder/"
nano config.yaml
