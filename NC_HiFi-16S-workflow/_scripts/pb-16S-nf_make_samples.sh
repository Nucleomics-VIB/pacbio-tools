#!/bin/bash

# pb-16S-nf_make_samples.sh
# create pb-16S-nf run_samples.tsv file from HiFi demultiplexed read folder
#
# Stephane Plaisance (VIB-NC) 2023/10/20; v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB

while getopts ":f:p:" opt; do
  case $opt in
    f) readfolder="$OPTARG";;
    p) pos="$OPTARG";;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-f <readfolder (default: fastq_results)>] [-p <pos (default: 3)]"
      exit 1
      ;;
  esac
done

# Set default values
if [ -z "$readfolder" ]; then
  readfolder="fastq_results"
fi

if [ -z "$pos" ]; then
  pos=3
fi

# Check if the folder exists
if [ ! -d "$readfolder" ]; then
  echo "Error: The folder '$readfolder' does not exist."
  exit 1
fi

echo -e "sample-id\tabsolute-file-path" > run_samples.tsv

# get the real full path even when it is a link with readlink
find "$readfolder" -name "*.fastq.gz" -exec readlink -f {} \; | while read -r fq; do
  # extract barcode pair from file name at the specified position
  bc=$(basename "$fq" | cut -d "." -f "$pos")
  # echo both to the run_sample file
  echo -e "${bc}\t${fq}";
done | tr -d '\r' >> run_samples.tsv
