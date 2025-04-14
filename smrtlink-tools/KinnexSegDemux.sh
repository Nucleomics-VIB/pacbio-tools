#!/bin/bash

# KinnexSegDemux.sh
# 
# Author: SP@NC (AI)
# Description: This script automates the segmentation, demultiplexing, and
#  conversion processes for Kinnex 16S BAM files using skera and lima
# Version: 1.1; 2025-02-10
# Version: 1.2; 2025-04-11
# Version: 1.3; 2025-04-11 - Added global command logging
# Version: 1.4; 2025-04-11 - Added command version logging
# Version: 1.5; 2025-04-14 - Added -k parameter for Kinnex primers file
# Version: 1.6; 2025-04-15 - Fixed Conda initialization issues
# Version: 1.7; 2025-04-15 - Simplified with full parallel processing

# Define usage function at the top
usage() {
    echo "Usage: $0 [-m movie] [-t threads] [-b barcodes] [-k kinnex_primers] [-l minlen] [-p prefix]"
    echo "Required:"
    echo "  -m  Movie name (input BAM prefix)"
    echo "Options:"
    echo "  -t  Number of threads (default: 10)"
    echo "  -b  skera barcode file (default: mas12_primers.fasta)"
    echo "  -k  lima barcode file (default: Kinnex16S_384plex_primers.fasta)"
    echo "  -l  Minimum length for lima (default: 50)"
    echo "  -p  Prefix for output files (default: hifi-reads)"
    echo "  -h  Show this help message"
}

# Create global log file with timestamp
GLOBAL_LOG="KinnexDemux_$(date +%Y%m%d_%H%M%S).log"
echo "KinnexSegDemux execution log - $(date)" > "$GLOBAL_LOG"
echo "Command: $0 $@" >> "$GLOBAL_LOG"

# Function to initialize conda properly
init_conda() {
    # Try to find conda installation
    local conda_path
    conda_path=$(which conda 2>/dev/null || command -v conda 2>/dev/null)
    
    if [ -z "$conda_path" ]; then
        echo "Error: Conda not found in PATH" | tee -a "$GLOBAL_LOG"
        exit 1
    fi

    # Get the base conda directory
    local conda_base
    conda_base=$(dirname "$(dirname "$conda_path")")
    
    # Source the conda.sh script
    if [ -f "$conda_base/etc/profile.d/conda.sh" ]; then
        source "$conda_base/etc/profile.d/conda.sh"
    else
        echo "Error: Could not find conda.sh initialization script" | tee -a "$GLOBAL_LOG"
        exit 1
    fi
}

# Initialize conda before any conda commands
init_conda

# Function to get detailed version information
get_command_versions() {
    echo >> "$GLOBAL_LOG"
    echo "=== Command Versions ===" >> "$GLOBAL_LOG"
    
    # Get lima version
    echo "lima --version output:" >> "$GLOBAL_LOG"
    lima --version 2>&1 | sed 's/^/  /' >> "$GLOBAL_LOG"
    echo >> "$GLOBAL_LOG"
    
    # Get skera version
    echo "skera --version output:" >> "$GLOBAL_LOG"
    skera --version 2>&1 | sed 's/^/  /' >> "$GLOBAL_LOG"
    echo >> "$GLOBAL_LOG"
}

# Function to log and execute commands
log_and_exec() {
    local cmd="$1"
    echo >> "$GLOBAL_LOG"
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$GLOBAL_LOG"
    echo "# $cmd" | tee -a "$GLOBAL_LOG"
    eval "$cmd" 2>&1 | tee -a "$GLOBAL_LOG"
    local status=$?
    echo "Exit status: $status" >> "$GLOBAL_LOG"
    return $status
}

# Load conda environment
myenv="Kinnex_16S_decat_demux_env"
log_and_exec "source /opt/miniconda3/etc/profile.d/conda.sh"
log_and_exec "conda activate ${myenv}" || {
    echo "# The conda environment ${myenv} was not found on this machine." | tee -a "$GLOBAL_LOG"
    echo "# Please read the top part of the script!" | tee -a "$GLOBAL_LOG"
    exit 1
}

# Get command versions after activating environment
get_command_versions

# Default values for optional arguments
movie=""
nthr=10
barcodes="mas12_primers.fasta"
kinnex_primers="Kinnex16S_384plex_primers.fasta"
minlen=50
pfx="hifi-reads"

# Parse optional arguments using getopts
while getopts "m:t:b:k:l:p:h" opt; do
    case $opt in
        m) movie="$OPTARG" ;;
        t) nthr="$OPTARG" ;;
        b) barcodes="$OPTARG" ;;
        k) kinnex_primers="$OPTARG" ;;
        l) minlen="$OPTARG" ;;
        p) pfx="$OPTARG" ;;
        h) usage; exit 0 ;;
        *) usage >&2; exit 1 ;;
    esac
done

# Check if the movie variable is set, else exit with error
if [[ -z "$movie" ]]; then
    echo "Error: Movie name (-m) is required." >&2 | tee -a "$GLOBAL_LOG"
    exit 1
fi

# Check if the kinnex and 16S primers files exists
if [[ ! -f "$barcodes" ]]; then
    echo "Error: Barcode file $barcodes not found." >&2 | tee -a "$GLOBAL_LOG"
    exit 1
fi

if [[ ! -f "$kinnex_primers" ]]; then
    echo "Error: Kinnex primers file $kinnex_primers not found." >&2 | tee -a "$GLOBAL_LOG"
    exit 1
fi

# Segmentation from a single Kinnex BAM barcode
log_and_exec "mkdir -p bc{01..04}/skera_out"

# Run all skera commands in parallel
for bc in {01..04}; do
    # Check if the skera step has already been completed
    if [[ -f "bc${bc}/skera_out/done.flag" ]]; then
        echo "Skipping skera for bc${bc}, already completed." | tee -a "$GLOBAL_LOG"
        continue
    fi

    # Validate input files exist or die
    if [[ ! -f "hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam" ]]; then
        echo "Error: Input file hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam not found." >&2 | tee -a "$GLOBAL_LOG"
        exit 1
    fi

    cmd="skera split \
      -j ${nthr} \
      --log-level INFO \
      --log-file bc${bc}/skera_out/skera_log.txt \
      hifi_reads/${movie}.hifi_reads.bcM00${bc}.bam \
      ${barcodes} \
      bc${bc}/skera_out/seg_hifi-reads.bam"

    # Run skera in background and create flag on success
    (log_and_exec "$cmd" && touch "bc${bc}/skera_out/done.flag") &
done

wait  # Ensure all skera processes finish before proceeding
echo "Segmentation completed at $(date)" >> "$GLOBAL_LOG"

# Demultiplexing step using lima - all in parallel
for skera in $(find . -type d -name skera_out | sort -u); do
    bc=$(basename $(dirname ${skera})) # eg. bc01

    # Check if the lima step has already been completed
    if [[ -f "${bc}/lima_out/done.flag" ]]; then
        echo "Skipping lima for ${bc}, already completed." | tee -a "$GLOBAL_LOG"
        continue
    fi

    log_and_exec "mkdir -p ${bc}/lima_out"

    # Locate the barcode file
    barcode_file=$(find . -type f -name "*_${bc}_SMRTLink_Barcodefile*.csv" | head -n 1)
    if [[ -z "$barcode_file" ]]; then
        echo "Error: Barcode file for ${bc} not found." >&2 | tee -a "$GLOBAL_LOG"
        exit 1
    fi

    cmd="lima \
      -j ${nthr} \
      --log-level INFO \
      --log-file ${bc}/lima_out/lima_log.txt \
      --split-named \
      --split-subdirs \
      --min-length ${minlen} \
      --hifi-preset ASYMMETRIC \
      --biosample-csv \"$barcode_file\" \
      ${bc}/skera_out/seg_hifi-reads.bam \
      ${kinnex_primers} \
      ${bc}/lima_out/${pfx}.bam"

    # Run lima in background and create flag on success
    (log_and_exec "$cmd" && touch "${bc}/lima_out/done.flag") &
done

wait  # Ensure all lima processes finish before exiting
echo "Demultiplexing completed at $(date)" >> "$GLOBAL_LOG"

echo "Processing completed successfully." | tee -a "$GLOBAL_LOG"
