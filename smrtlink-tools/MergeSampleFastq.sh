#!/bin/bash

# script: MergeSampleFastq.sh
#
# Description: This script searches for fastq.gz files in the current path
#              that partially match a sample list provided in a text list
#              It then merges the found files into a single fastq.gz file
#              in a specified output folder.
# Author: SP@NC (+GitHub Copilot)
# Date: 2025-02-13
# Version: 1.4

prefix=""
sample_list=""
outfolder="merged_fastq"

# Function to display usage
usage() {
    echo "Usage: $0 -s <sample_list.txt> [-p <prefix>] [-o <output_folder>]"
    echo "  -s <sample_list.txt>: Path to the sample list file (required)"
    echo "  -p <prefix>: Optional prefix for output file names"
    echo "  -o <output_folder>: Output folder name (default: merged_fastq)"
    echo "  -h: Display this help message"
    exit 1
}

# Parse command line options
while getopts ":s:p:o:h" opt; do
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

# loop through the sample list
while read smpl; do

    # Find fastq.gz files whose names contain the sample name in the current path and subfolders
    files=$(find . -type f -name "${smpl}.fastq.gz" | sort | tr "\n" " ")

    # Check if any files were found
    if [ -n "${files}" ]; then
        echo "Found files for sample ${smpl}:"
        echo "${files}"

        # Merge the files into a single fastq.gz file
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

done < "${sample_list}"

echo "# done merging ${cnt} samples"