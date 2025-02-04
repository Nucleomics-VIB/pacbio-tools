#!/bin/bash

# Script: SplitLimaCounts.sh
# Description: This script creates subset files based on matching barcodes from a barcode CSV file and a Lima Coun
# the project number has been added to the barcode CSV file as extra column and is used to split and to name the s
# Usage: ./subset_counts.sh -b BARCODES_CSV -i INFO_TSV
# Version: 1.0.0
# Date: 2025-02-03
# Author: SP@NC (AI Assistant)

# Default file names
barcodes_file=""
info_file=""

# Function to display usage information
usage() {
    echo "Usage: $0 -b BARCODES_CSV -i INFO_TSV"
    echo "  -b BARCODES_CSV : Path to the barcodes CSV file"
    echo "  -i INFO_TSV     : Path to the information TSV file"
    echo "  -h              : Display this help message"
    exit 1
}1

# Parse command line options
while getopts ":b:i:h" opt; do
    case $opt in
        b) barcodes_file="$OPTARG" ;;
        i) info_file="$OPTARG" ;;
        h) usage ;;
        \?) echo "Invalid option: -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if both input files are provided
if [[ -z "$barcodes_file" ]] || [[ -z "$info_file" ]]; then
    echo "Error: Both barcodes CSV and information TSV files are required."
    usage
fi

# Check if input files exist
if [[ ! -f "$barcodes_file" ]] || [[ ! -f "$info_file" ]]; then
    echo "Error: Input files not found."
    usage
fi

# store the header to be added to all output files
tsv_header=$(head -n 2 "$info_file")

echo "Processing CSV file..."
tail -n +2 "$barcodes_file" | while IFS=',' read -r barcode_pair _ proj_number; do
    echo "Processing barcode pair: $barcode_pair, Project: $proj_number"
    output_file="subset_${proj_number}.tsv"
    if [[ ! -f "$output_file" ]]; then
        echo "$tsv_header" > "$output_file"
        echo "Created new file: $output_file"
    fi
    matching_lines=$(awk -v bp="$barcode_pair" '
        $3 "--" $4 == bp {print;}
    ' "$info_file")
    echo "$matching_lines" >> "$output_file"
    echo "Appended matching lines to $output_file"
    echo "---"
done
echo "Subset files have been created."

# Print the content of the first few lines of each output file
for file in subset_*.tsv; do
    echo "Content of $file:"
    head -n 7 "$file"
    echo "---"
done
