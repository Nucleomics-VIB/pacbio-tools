#!/bin/bash

# script: split_fastq_by_project_v2.sh
# Copy fastq files to project-specific folders based on barcode mapping
# Author: SP@NC
# Date: 2025-05-05
# Version: 2.2 - Fixed file copying logic and improved error handling
#   - Added support for barcode2name.csv format
#   - Added parallel processing
#   - Added more flexible input/output options
#   - Fixed pipe subshell variable scope issue
#   - Fixed file copying logic for multiple files

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
    local success=0
    
    # Find files matching the barcode pattern
    local files=$(find "$infolder" -type f -name "*${barcode}*.fastq.gz" | sort)
    
    if [ -z "$files" ]; then
        echo "No files found for barcode: $barcode (sample: $sample)" | tee -a "$logfile"
        return 1
    fi
    
    echo "Processing barcode: $barcode (sample: $sample)" | tee -a "$logfile"
    echo "Found files:" >> "$logfile"
    echo "$files" >> "$logfile"
    
    # Process each file found
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        
        # Get the base filename
        local basename=$(basename "$file")
        
        # Determine output filename
        local outname
        if [ -n "$prefix" ]; then
            # If multiple files, append counter or use original name structure
            if [ $(echo "$files" | wc -l) -gt 1 ]; then
                outname="${prefix}_${sample}_${basename}"
            else
                outname="${prefix}_${sample}.fastq.gz"
            fi
        else
            # If multiple files, use sample name with original structure
            if [ $(echo "$files" | wc -l) -gt 1 ]; then
                outname="${sample}_${basename}"
            else
                outname="${sample}.fastq.gz"
            fi
        fi
        
        echo "Copying: $file -> $outfolder/$outname" | tee -a "$logfile"
        
        # Copy the file with proper quoting
        if cp "$file" "$outfolder/$outname" 2>> "$logfile"; then
            echo "Success: $outname" >> "$logfile"
            ((success++))
        else
            echo "Failed to copy: $file" | tee -a "$logfile"
        fi
        
    done <<< "$files"
    
    echo "Copied $success files for sample: $sample" | tee -a "$logfile"
    echo "----------------------------------------" >> "$logfile"
    
    return 0
}

# Process the barcode file and filter for the requested project
echo "Processing barcode file and filtering for project: $project"
job_count=0
total_samples=0

# Read and process the CSV file
while IFS=',' read -r barcode bio_sample; do
    # Remove carriage returns and newlines
    barcode=$(echo "$barcode" | tr -d '\r\n' | xargs)
    bio_sample=$(echo "$bio_sample" | tr -d '\r\n' | xargs)
    
    # Skip empty lines or header
    [ -z "$barcode" ] || [ -z "$bio_sample" ] && continue
    [ "$barcode" = "Barcode" ] && continue
    
    # Check if the bio_sample contains the project name
    if [[ "$bio_sample" == *"$project"* ]]; then
        echo "Found matching sample: $bio_sample (barcode: $barcode)"
        ((total_samples++))
        
        # Run copy in background for parallelization
        copy_file "$bio_sample" "$barcode" &
        
        ((job_count++))
        
        # Wait if reached max parallel jobs
        if [ $job_count -ge $threads ]; then
            echo "Waiting for $job_count background jobs to complete..."
            wait
            job_count=0
        fi
    fi
done < <(cat "$barcode_file")

# Wait for any remaining jobs
echo "Waiting for remaining background jobs to complete..."
wait

echo "----------------------------------------" >> "$logfile"
echo "Copy operation completed at $(date)" >> "$logfile"
echo "Total samples processed: $total_samples" >> "$logfile"

echo "Copy operation completed! Results are in $outfolder"
echo "Total samples processed: $total_samples"
echo "Log file: $logfile"