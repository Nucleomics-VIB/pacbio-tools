#!/bin/bash

# script: split_fastq_by_project_v2.sh
# Copy fastq files to project-specific folders based on barcode mapping
# Author: SP@NC (+AI)
# Date: 2025-05-05
# Version: 2.0 - Complete rewrite with improved functionality
#   - Added support for barcode2name.csv format
#   - Added parallel processing
#   - Added more flexible input/output options

# Default values
infolder="fastq_results"
threads=4
prefix=""

# Function to display usage
usage() {
    echo "Usage: $0 -b <barcode_file.csv> -p <project> [-i <input_folder>] [-o <output_folder>] [-t <threads>] [-x <prefix>]"
    echo "  -b <barcode_file.csv>: CSV file mapping barcodes to sample names (required)"
    echo "  -p <project>: Project name to filter/organize files (required)"
    echo "  -i <input_folder>: Source folder containing fastq files (default: fastq_results)"
    echo "  -o <output_folder>: Custom output folder (default: <input_folder>_<project>)"
    echo "  -t <threads>: Number of parallel copy operations (default: 4)"
    echo "  -x <prefix>: Optional prefix for output files"
    echo "  -h: Display this help message"
    exit 1
}

# Parse command line options
while getopts ":b:p:i:o:t:x:h" opt; do
    case $opt in
        b) barcode_file="$OPTARG" ;;
        p) project="$OPTARG" ;;
        i) infolder="$OPTARG" ;;
        o) outfolder="$OPTARG" ;;
        t) threads="$OPTARG" ;;
        x) prefix="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required arguments are provided
if [ -z "$barcode_file" ]; then
    echo "Error: Barcode file is required."
    usage
fi

if [ -z "$project" ]; then
    echo "Error: Project name is required."
    usage
fi

# Set output folder if not specified
if [ -z "$outfolder" ]; then
    outfolder="${infolder}_${project}"
fi

# Check if input files and folders exist
if [ ! -f "$barcode_file" ]; then
    echo "Error: Barcode file '$barcode_file' not found."
    exit 1
fi

if [ ! -d "$infolder" ]; then
    echo "Error: Source folder '$infolder' not found."
    exit 1
fi

# Create output directory
mkdir -p "$outfolder"

# Create log file
logfile="${outfolder}/copy_log_$(date +%Y%m%d_%H%M%S).txt"
echo "Starting file copy for project: $project" > "$logfile"
echo "Using barcode file: $barcode_file" >> "$logfile"
echo "Source folder: $infolder" >> "$logfile"
echo "Destination folder: $outfolder" >> "$logfile"
echo "----------------------------------------" >> "$logfile"

# Function to copy files based on barcode
copy_file() {
    local sample="$1"
    local barcode="$2"
    
    # Find files matching the barcode pattern
    local files=$(find "$infolder" -type f -name "*${barcode}*.fastq.gz" | sort)
    
    if [ -z "$files" ]; then
        echo "No files found for barcode: $barcode (sample: $sample)" >> "$logfile"
        return 1
    fi
    
    # Determine output filename
    local outname
    if [ -n "$prefix" ]; then
        outname="${prefix}_${sample}.fastq.gz"
    else
        outname="${sample}.fastq.gz"
    fi
    
    echo "Copying files for barcode: $barcode (sample: $sample)" >> "$logfile"
    echo "Found files:" >> "$logfile"
    echo "$files" >> "$logfile"
    echo "Target: $outfolder/$outname" >> "$logfile"
    
    # Copy the file
    cp $files "$outfolder/$outname" 2>> "$logfile"
    
    return $?
}

# Process the barcode file and filter for the requested project
echo "Processing barcode file and filtering for project: $project"
job_count=0

# Read CSV file line by line (skip header)
tail -n +2 "$barcode_file" | while IFS=',' read -r barcode bio_sample; do
    # Remove carriage returns and newlines
    barcode=$(echo "$barcode" | tr -d '\r\n')
    bio_sample=$(echo "$bio_sample" | tr -d '\r\n')
    
    # Skip empty lines
    [ -z "$barcode" ] || [ -z "$bio_sample" ] && continue
    
    # Check if the bio_sample contains the project name
    if [[ "$bio_sample" == *"$project"* ]]; then
        echo "Found matching sample: $bio_sample (barcode: $barcode)"
        
        # Run copy in background for parallelization
        copy_file "$bio_sample" "$barcode" &
        
        ((job_count++))
        
        # Wait if reached max parallel jobs
        if [ $job_count -ge $threads ]; then
            wait
            job_count=0
        fi
    fi
done

# Wait for any remaining jobs
wait

echo "----------------------------------------" >> "$logfile"
echo "Copy operation completed at $(date)" >> "$logfile"
echo "Copy operation completed! Results are in $outfolder"
echo "Log file: $logfile"