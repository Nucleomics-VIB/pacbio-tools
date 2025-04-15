#!/bin/bash

# Script: Kinnex_bam2fastq.sh
# Author: SP@NC (AI)
# Date: 2025-04-15
# Description: Converts BAM files from Kinnex lima output to FASTQ
# based on a mapping CSV file, running conversions in parallel.
# Version: 1.1 - Added global flag file instead of individual ones

# Function to display usage information
usage() {
    echo "Usage: $0 -b <bam_folder> -c <barcode_csv_file> [-n <num_threads>] [-i <in_prefix>]"
    echo "  -b : BAM/Lima folder containing the input BAM files (required)"
    echo "  -c : Barcode to sample name CSV file (required)"
    echo "  -n : Number of parallel jobs (default: 8)"
    echo "  -i : Prefix for the BAM files (default: 'hifi-reads')"
    echo "  -h : Show this help message"
    exit 1
}

# Create log file with timestamp
LOG_FILE="kinnex_bam2fastq_$(date +%Y%m%d_%H%M%S).log"
echo "kinnex_bam2fastq execution log - $(date)" > "$LOG_FILE"
echo "Command: $0 $@" >> "$LOG_FILE"

# Function to log and execute commands
log_and_exec() {
    local cmd="$1"
    echo "=== $(date '+%Y-%m-%d %H:%M:%S') ===" >> "$LOG_FILE"
    echo "# $cmd" | tee -a "$LOG_FILE"
    eval "$cmd" 2>&1 | tee -a "$LOG_FILE"
    local status=$?
    echo "Exit status: $status" >> "$LOG_FILE"
    return $status
}

# Activate conda environment or die
myenv="Kinnex_16S_decat_demux_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || {
    echo "# The conda environment ${myenv} was not found on this machine" | tee -a "$LOG_FILE"
    echo "# Please read the top part of the script!" | tee -a "$LOG_FILE"
    exit 1
}

# Default values
nthr=8
in_prefix='hifi-reads'
bam_folder=""
barcode_csv=""

# Parse command line options
while getopts ":b:c:n:i:h" opt; do
    case $opt in
        b) bam_folder="$OPTARG" ;;
        c) barcode_csv="$OPTARG" ;;
        n) nthr="$OPTARG" ;;
        i) in_prefix="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required arguments are provided
if [ -z "$bam_folder" ]; then
    echo "Error: BAM folder is required." | tee -a "$LOG_FILE"
    usage
fi

if [ -z "$barcode_csv" ]; then
    echo "Error: Barcode CSV file is required." | tee -a "$LOG_FILE"
    usage
fi

# Check if the input folder and CSV file exist
if [ ! -d "$bam_folder" ]; then
    echo "Error: BAM folder '$bam_folder' does not exist." | tee -a "$LOG_FILE"
    exit 1
fi

if [ ! -f "$barcode_csv" ]; then
    echo "Error: Barcode CSV file '$barcode_csv' does not exist." | tee -a "$LOG_FILE"
    exit 1
fi

# Create the output directory
outdir="fastq_reads"
log_and_exec "mkdir -p $outdir"

# Create a temporary directory for status tracking
tmp_dir=$(mktemp -d)
echo "Using temporary directory for status tracking: $tmp_dir" >> "$LOG_FILE"

# Count samples before processing
total_samples=$(tail -n +2 "$barcode_csv" | grep -v "^$" | wc -l)
echo "Found $total_samples samples in CSV file" | tee -a "$LOG_FILE"

# Counter for parallel jobs
job_count=0
processed_count=0

# Process the CSV file (skip header)
while IFS=, read -r barcode biosample; do
    # Skip empty lines and header
    [ -z "$barcode" ] && continue
    [[ "$barcode" == "Barcode" ]] && continue

    # Remove carriage return from biosample and barcode, replace spaces with underscores
    biosample=$(echo "${biosample}" | tr -d '\r' | tr ' ' '_')
    barcode=$(echo "${barcode}" | tr -d '\r')
    
    ((processed_count++))
    echo "Processing barcode: $barcode -> $biosample ($processed_count of $total_samples)" | tee -a "$LOG_FILE"
    
    # Find the BAM file matching the barcode pattern
    matching_bam=$(find "$bam_folder" -type f -name "*${barcode}*.bam" | grep -v '\.pbi$' | head -n 1)
    
    if [ -z "$matching_bam" ]; then
        echo "Warning: No BAM file found for barcode $barcode" | tee -a "$LOG_FILE"
        # Mark this job as failed
        echo "1" > "$tmp_dir/${biosample}.failed"
        continue
    fi
    
    echo "Found BAM file: $matching_bam" | tee -a "$LOG_FILE"
    
    # Run bam2fastq in the background with status tracking
    (
        cmd="bam2fastq -j $nthr -o \"$outdir/${biosample}\" \"$matching_bam\""
        if log_and_exec "$cmd"; then
            echo "0" > "$tmp_dir/${biosample}.status"
        else
            echo "1" > "$tmp_dir/${biosample}.status"
        fi
    ) &
    
    # Increment job counter
    ((job_count++))
    
    # Wait if we've reached the maximum number of parallel jobs
    if [ $job_count -ge $nthr ]; then
        wait
        job_count=0
    fi
    
done < <(sed -e '/^\s*$/d' "$barcode_csv")

# Wait for any remaining jobs to finish
wait

# Check if all jobs completed successfully
failures=0
for status_file in "$tmp_dir"/*.status "$tmp_dir"/*.failed; do
    # Skip if no files match the pattern
    [ ! -e "$status_file" ] && continue
    
    if [ "$(cat "$status_file")" == "1" ]; then
        ((failures++))
    fi
done

# Create global flag file only if all jobs succeeded
if [ $failures -eq 0 ]; then
    touch "$outdir/all_conversions_complete.flag"
    echo "All conversions completed successfully!" | tee -a "$LOG_FILE"
else
    echo "Warning: $failures conversions failed. Check the log for details." | tee -a "$LOG_FILE"
fi

# Clean up temporary directory
rm -rf "$tmp_dir"

echo "Processing complete! FASTQ files are available in the '$outdir' directory." | tee -a "$LOG_FILE"
echo "See $LOG_FILE for detailed execution log." | tee -a "$LOG_FILE"