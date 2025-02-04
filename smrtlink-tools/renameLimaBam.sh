#!/bin/bash

# Script: renameLimaBam.sh
# Author: SP@NC (AI Assistant)
# Date: 2025-01-31
# Description: Renames and copies .bam and .bam.bai files from Lima output
#              based on a mapping CSV file, organizing files in a new directory.

# Check if the input CSV file is provided
if [ $# -eq 0 ]; then
    echo "Error: Input CSV file is required."
    echo "Usage: $0 <input_csv_file>"
    exit 1
fi

input_csv="${1}"
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

# activate conda env or die
myenv="Kinnex_16S_decat_demux_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || \
  ( echo "# the conda environment ${myenv} was not found on this machine" ;
    echo "# please read the top part of the script!" \
    && exit 1 )

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
    if [ -f "${source_dir}/HiFi.${barcode}.bam" ]; then
        cp "${source_dir}/HiFi.${barcode}.bam" "${outbam}/${biosample}.bam"
        cp "${source_dir}/HiFi.${barcode}.bam.pbi" "${outbam}/${biosample}.bam.pbi"
        echo "..Copied HiFi.${barcode}.bam to ${outbam}/${biosample}.bam"
    else
        echo "Warning: HiFi.${barcode}.bam not found in ${source_dir}"
    fi

    # create fastq version
    bam2fastq -j 8 -o "${outfastq}/${biosample}" "${outbam}/${biosample}.bam"

done

echo "Processing complete."