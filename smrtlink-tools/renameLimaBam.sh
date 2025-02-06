#!/bin/bash

# Script: renameLimaBam.sh
# Author: SP@NC (AI)
# Date: 2025-02-06
# Description: Renames and copies .bam and .bam.bai files from Lima output
# based on a mapping CSV file, organizing files in a new directory.
# also create fastq version for data delivery

# Function to display usage information
usage() {
    echo "Usage: $0 -c <input_csv_file> [-n <num_threads>] [-p <prefix>]"
    echo "  -c : Input CSV file (required)"
    echo "  -n : Number of threads (default: 8)"
    echo "  -p : Prefix for input files (default: 'hifi-reads')"
    exit 1
}

# activate conda env or die
myenv="Kinnex_16S_decat_demux_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || \
  ( echo "# the conda environment ${myenv} was not found on this machine" ;
    echo "# please read the top part of the script!" \
    && exit 1 )

# Default values
nthr=8
pfx='hifi-reads'
input_csv=""

# Parse command line options
while getopts ":c:n:p:" opt; do
    case $opt in
        c) input_csv="$OPTARG" ;;
        n) nthr="$OPTARG" ;;
        p) pfx="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if the input CSV file is provided
if [ -z "$input_csv" ]; then
    echo "Error: Input CSV file is required."
    usage
fi

infolder=lima_out
outbam=bam_out
outfastq=fastq_out

# Create the destination directories
mkdir -p ${outbam} ${outfastq}

# Check if the input CSV file exists
if [ ! -f "${input_csv}" ]; then
    echo "Error: Input CSV file '${input_csv}' does not exist."
    exit 1
fi

# Remove trailing empty lines and process the CSV file
sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${input_csv}" | tail -n +2 | while IFS=',' read -r barcode biosample
do
    # Source directory
    source_dir="${infolder}/${barcode}"

    # Remove carriage return from biosample
    biosample=$(echo "${biosample}" | tr -d '\r' | tr ' ' '_')

    # Check if source directory exists
    if [ ! -d "${source_dir}" ]; then
        echo "Warning: Source directory ${source_dir} does not exist. Skipping..."
        continue
    fi

    # Copy .bam and .bam.bai files
    if [ -f "${source_dir}/${pfx}.${barcode}.bam" ]; then
        cp "${source_dir}/${pfx}.${barcode}.bam" "${outbam}/${biosample}.bam"
        cp "${source_dir}/${pfx}.${barcode}.bam.pbi" "${outbam}/${biosample}.bam.pbi"
        echo "..Copied ${pfx}.${barcode}.bam to ${outbam}/${biosample}.bam"
    else
        echo "Warning: ${pfx}.${barcode}.bam not found in ${source_dir}"
    fi

    # create fastq version
    bam2fastq -j ${nthr} -o "${outfastq}/${biosample}" "${outbam}/${biosample}.bam"

done

echo "Processing complete."
