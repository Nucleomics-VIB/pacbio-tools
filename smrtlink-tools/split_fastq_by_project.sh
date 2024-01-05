#!/bin/bash

# script: split_fastq_by_project.sh
# copy fastq of a given project to a new folder
# SP@NC 2023-12-20
# v1.0

# Function to read barcodes from file1
read_barcodes() {
    file_path=$1
    if [ ! -f "$file_path" ]; then
        echo "Error: File '$file_path' not found."
        exit 1
    fi

    # Use awk to extract the first column (assuming it's the barcode column)
    awk -F ',' 'NR > 1 {print $1}' "$file_path"
}

# Function to copy files based on barcodes and project
copy_files() {
    barcode_list=($1)
    project=$2
    source_folder=$3
    dest_folder=$4

    if [ ! -d "$source_folder" ]; then
        echo "Error: Source folder '$source_folder' not found."
        exit 1
    fi

    # Create destination folder if it doesn't exist
    mkdir -p "$dest_folder"

    # Loop through each barcode and copy fastq files
    for barcode in "${barcode_list[@]}"; do
      cp "${source_folder}/${barcode}.fastq.gz" "${dest_folder}/" 2>/dev/null
    done

    echo "Files copied to $dest_folder"
}

# Check if the correct number of command-line arguments are provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 file1.csv project"
    exit 1
fi

# Get file paths and project from command-line arguments
file1_path=$1
project=$2
infolder="fastq_results"

# Read barcodes from file1 into an array
barcode_list=($(read_barcodes "$file1_path"))

# Copy fastq files to new folder
copy_files "${barcode_list[*]}" "$project" "${infolder}" "${infolder}_${project}"
