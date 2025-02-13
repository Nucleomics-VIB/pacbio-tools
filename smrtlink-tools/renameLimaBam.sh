#!/bin/bash

# Script: renameLimaBam.sh
# Author: SP@NC (AI)
# Date: 2025-02-13
# version 1.4
# Description: Renames and copies .bam and .bam.bai files from Lima output
# based on a mapping CSV file, organizing files in a new directory.
# also create fastq version for data delivery

# Function to display usage information
usage() {
    echo "Usage: $0 -c <input_csv_file> [-n <num_threads>] [-i <in_prefix>] [-o <out_prefix>]"
    echo "  -c : Input CSV file (required)"
    echo "  -n : Number of threads (default: 8)"
    echo "  -i : Prefix for the input bam file (default: 'hifi-reads')"
    echo "  -o : Optional prefix for output files (default: none)"
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
in_prefix='hifi-reads'
input_csv=""
out_prefix=""

# Parse command line options
while getopts ":c:n:i:o:" opt; do
    case $opt in
        c) input_csv="$OPTARG" ;;
        n) nthr="$OPTARG" ;;
        i) in_prefix="$OPTARG" ;;
        o) out_prefix="$OPTARG" ;;
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

# sample counter
cnt=0

# loop in the CSV file
while IFS=',' read -r barcode biosample; do

    # count processed files
    ((cnt++))

    # Source directory
    source_dir="${infolder}/${barcode}"

    # Remove carriage return from biosample
    biosample=$(echo "${biosample}" | tr -d '\r' | tr ' ' '_')

    # Check if source directory exists
    if [ ! -d "${source_dir}" ]; then
        echo "Warning: Source directory ${source_dir} does not exist. Skipping..."
        continue
    fi

    # Prepare output filename with optional prefix
    if [ -n "$out_prefix" ]; then
        output_name="${out_prefix}_${biosample}"
    else
        output_name="${biosample}"
    fi

    # Copy .bam and .bam.bai files
    if [ -f "${source_dir}/${in_prefix}.${barcode}.bam" ]; then
        cp "${source_dir}/${in_prefix}.${barcode}.bam" "${outbam}/${output_name}.bam"
        cp "${source_dir}/${in_prefix}.${barcode}.bam.pbi" "${outbam}/${output_name}.bam.pbi"
        echo "..Copied ${in_prefix}.${barcode}.bam to ${outbam}/${output_name}.bam"
    else
        echo "Warning: ${in_prefix}.${barcode}.bam not found in ${source_dir}"
    fi

    # create fastq version
    bam2fastq -j ${nthr} -o "${outfastq}/${output_name}" "${outbam}/${output_name}.bam"

# Remove trailing empty lines and process the CSV file
done < <(sed -e :a -e '/^\n*$/{$d;N;ba' -e '}' "${input_csv}" | awk 'NF' | tail -n +2)

echo "Processing complete for ${cnt} samples."
