#!/bin/bash

# script: SubsetLimaCounts.sh
# create subset of a .lima_counts.txt file based on a barcode file
# SP@NC 2023-12-20
# v1.1 (modified to use optargs and renamed)

# Function to display usage information
usage() {
    echo "Usage: $0 -b <barcodes.csv> -l <lima-counts.txt> -o <output.txt>"
    echo "Options:"
    echo "  -b    Path to the barcodes CSV file"
    echo "  -l    Path to the lima-counts.txt file"
    echo "  -o    Path to the output file"
    echo "  -h    Display this help message"
    exit 1
}

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

# Function to filter rows from file2 based on matching barcodes
filter_rows() {
    file1_barcodes=($1)
    file2_path=$2
    output_path=$3

    if [ ! -f "$file2_path" ]; then
        echo "Error: File '$file2_path' not found."
        exit 1
    fi

    # Convert the array to a comma-separated string
    barcodes_str=$(IFS=,; echo "${file1_barcodes[*]}")

    # Use awk to filter rows based on matching barcodes
    awk -F '\t' -v barcodes="$barcodes_str" '
      BEGIN {print "IdxFirst\tIdxCombined\tIdxFirstNamed\tIdxCombinedNamed\tCounts\tMeanScore"}
      NR > 1 {found=0; for (i=1; i<=NF; i++) {
        if (index(barcodes, $3 "--" $4) > 0) {
          found=1; break;
        }
      } if (found) print $0}' "$file2_path" > "$output_path"

    echo "Matching rows written to $output_path"
}

# Initialize variables
barcodes_file=""
lima_counts_file=""
output_file=""

# Parse command-line options
while getopts ":b:l:o:h" opt; do
    case $opt in
        b) barcodes_file="$OPTARG" ;;
        l) lima_counts_file="$OPTARG" ;;
        o) output_file="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if all required options are provided
if [ -z "$barcodes_file" ] || [ -z "$lima_counts_file" ] || [ -z "$output_file" ]; then
    echo "Error: Missing required options."
    usage
fi

# Read barcodes from file1 into an array
file1_barcodes=($(read_barcodes "$barcodes_file"))

# Filter rows from file2 based on matching barcodes and write to a new file
filter_rows "${file1_barcodes[*]}" "$lima_counts_file" "$output_file"
