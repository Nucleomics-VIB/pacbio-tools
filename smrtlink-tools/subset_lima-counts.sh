#!/bin/bash

# script: subset_lima-counts.sh
# create subset of a .lima_counts.txt file based on a barcode file
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

# Check if the correct number of command-line arguments are provided
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 barcodes.csv lima-counts.txt output.txt"
    exit 1
fi

# Get file paths from command-line arguments
file1_path=$1
file2_path=$2
output_path=$3

# Read barcodes from file1 into an array
file1_barcodes=($(read_barcodes "$file1_path"))

# Filter rows from file2 based on matching barcodes and write to a new file
filter_rows "${file1_barcodes[*]}" "$file2_path" "$output_path"