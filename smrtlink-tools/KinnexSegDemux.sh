#!/bin/bash

# KinnexSegDemux.sh
# 
# Author: SP@NC (AI)
# Description: This script automates the segmentation, demultiplexing, and
#  conversion processes for Kinnex 16S BAM files using skera and lima
# Version: 1.1; 2025-02-10

# Load conda environment
myenv="Kinnex_16S_decat_demux_env"
source /opt/miniconda3/etc/profile.d/conda.sh
conda activate ${myenv} || {
    echo "# The conda environment ${myenv} was not found on this machine."
    echo "# Please read the top part of the script!" && exit 1
}

# Default values for optional arguments
movie=""
nthr=10
barcodes="mas12_primers.fasta"
minlen=50
pfx="hifi-reads"

# Parse optional arguments using getopts
while getopts "m:t:b:l:p:h" opt; do
    case $opt in
        m) movie="$OPTARG" ;;  # Movie name
        t) nthr="$OPTARG" ;;   # Number of threads
        b) barcodes="$OPTARG" ;; # Barcode file
        l) minlen="$OPTARG" ;; # Minimum length for lima
        p) pfx="$OPTARG" ;;    # Prefix for output files
        h) 
            echo "Usage: $0 [-m movie] [-t threads] [-b barcodes] [-l minlen] [-p prefix]"
            exit 0 ;;
        *)
            echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
    esac
done

# Check if the movie variable is set, else exit with error
if [[ -z "$movie" ]]; then
    echo "Error: Movie name (-m) is required." >&2
    exit 1
fi

# Segmentation from a single Kinnex BAM barcode
mkdir -p bc{01..04}/skera_out

for bc in {01..04}; do

    # Validate input files exist or die
    if [[ ! -f "hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam" ]]; then
        echo "Error: Input file hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam not found." >&2
        exit 1
    fi

    cmd="skera split \
      -j ${nthr} \
      --log-level INFO \
      --log-file bc${bc}/skera_out/skera_log.txt \
      hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam \
      ${barcodes} \
      bc${bc}/skera_out/seg_hifi-reads.bam &"

    echo
    echo "# ${cmd}"
    eval ${cmd}

done

wait  # Ensure all background processes finish before proceeding

# Demultiplexing step using lima
for skera in $(find . -type d -name skera_out | sort -u); do

    bc=$(basename $(dirname ${skera})) # eg. bc01

    mkdir -p ${bc}/lima_out

    cmd="lima \
      -j ${nthr} \
      --log-level INFO \
      --log-file  ${bc}/lima_out/lima_log.txt \
      --split-named \
      --split-subdirs \
      --min-length ${minlen} \
      --hifi-preset ASYMMETRIC \
      --biosample-csv *_${bc}_SMRTLink_Barcodefile*.csv \
      ${bc}/skera_out/seg_hifi-reads.bam \
      Kinnex16S_384plex_primers.fasta \
      ${bc}/lima_out/${pfx}.bam &"

    echo
    echo "# ${cmd}"
    eval ${cmd}

done

wait  # Ensure all background processes finish before exiting

echo "Processing completed successfully."
