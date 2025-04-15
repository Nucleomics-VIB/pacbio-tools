#!/bin/bash

# script: MergeSampleFastq.sh
#
# Description: This script searches for fastq.gz files in the current path
#              that partially match a sample list provided in a text list
#              It then merges the found files into a single fastq.gz file
#              in a specified output folder.
# Author: SP@NC (+GitHub Copilot)
# Date: 2025-02-13
# Version: 1.5 - Added parallel processing support

prefix=""
sample_list=""
outfolder="merged_fastq"
threads=4  # Default number of parallel jobs

# Function to display usage
usage() {
    echo "Usage: $0 -s <sample_list.txt> [-p <prefix>] [-o <output_folder>] [-t <threads>]"
    echo "  -s <sample_list.txt>: Path to the sample list file (required)"
    echo "  -p <prefix>: Optional prefix for output file names"
    echo "  -o <output_folder>: Output folder name (default: merged_fastq)"
    echo "  -t <threads>: Number of parallel jobs (default: 4)"
    echo "  -h: Display this help message"
    exit 1
}

# Parse command line options
while getopts ":s:p:o:t:h" opt; do
    case $opt in
        s)
            sample_list="$OPTARG"
            ;;
        p)
            prefix="$OPTARG"
            ;;
        o)
            outfolder="$OPTARG"
            ;;
        t)
            threads="$OPTARG"
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Check if the sample list is provided
if [ -z "${sample_list}" ]; then
    echo "Error: Sample list file is required."
    usage
fi

# Check if the input file exists
if [ ! -f "${sample_list}" ]; then
    echo "Error: File '${sample_list}' not found!"
    exit 1
fi

# Create the output directory if it does not exist
mkdir -p ${outfolder}

cnt=0
job_count=0

# Function to process a single sample
process_sample() {
    local smpl="$1"
    local files=$(find . -type f -name "*${smpl}*.fastq.gz" | sort | tr "\n" " ")

    if [ -n "${files}" ]; then
        echo "Found files for sample ${smpl}:"
        echo "${files}"

        if [ -n "${prefix}" ]; then
            output_file="${outfolder}/${prefix}_${smpl}.fastq.gz"
        else
            output_file="${outfolder}/${smpl}.fastq.gz"
        fi

        zcat ${files} | bgzip -c > "${output_file}"

        echo "Merged file created: ${output_file}"
        ((cnt++))
    else
        echo "No files found for sample ${smpl}"
    fi
}

# Export the function and variables for parallel execution
export -f process_sample
export prefix
export outfolder
export cnt

# Read the sample list and process in parallel
cat "${sample_list}" | tr -d '\r' | xargs -I {} -P ${threads} bash -c 'process_sample "$@"' _ {}

echo "# done merging ${cnt} samples"