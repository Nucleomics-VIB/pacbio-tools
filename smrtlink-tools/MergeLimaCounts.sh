#!/bin/bash

# script: MergeLimaCounts.sh
#
# Description: Merge and aggregate Kinnex Lima TSV files from two or three runs
# Usage: ./MergeLimaCounts.sh -1 <input_file1> -2 <input_file2> [-3 <input_file3 (optional)>] [-o <output_file>]
# This script merges two or three TSV files containing Lima sequencing data based on
# IdxFirst and IdxCombined columns.
# It aggregates counts and calculates weighted mean scores (sum of scores / #runs).
# Author: SP@NC (+AI)
# Created: 2025-02-04
# Version: 1.3

# Default output file name
output_file="merged_output.tsv"

# Function to display usage
usage() {
    echo "Usage: $0 -1 <input_file1> -2 <input_file2> [-3 <input_file3 (optional)>] [-o <output_file>]"
    exit 1
}

# Parse command line options
while getopts ":1:2:3:o:" opt; do
    case $opt in
        1) input_file1="$OPTARG" ;;
        2) input_file2="$OPTARG" ;;
        3) input_file3="$OPTARG" ;;
        o) output_file="$OPTARG" ;;
        \?) echo "Invalid option -$OPTARG" >&2; usage ;;
        :) echo "Option -$OPTARG requires an argument." >&2; usage ;;
    esac
done

# Check if required arguments are provided
if [ -z "$input_file1" ] || [ -z "$input_file2" ]; then
    echo "Error: Input files 1 and 2 are required."
    usage
fi

# Write header to output file
head -n 1 "$input_file1" > "$output_file"

# Process and merge data
awk -F'\t' '
function safe_div(a, b) {
    return (b != 0) ? a / b : 0
}

FNR == 1 { next } # Skip header row for all files

{
    key = $1 "\t" $2
    counts[key] += $5
    weighted_sum[key] += $5 * $6
    data[key] = $0
}
END {
    for (key in counts) {
        split(data[key], fields, "\t")
        avg = int(safe_div(weighted_sum[key], counts[key]) + 0.5)
        fields[5] = counts[key]
        fields[6] = avg
        print fields[1] "\t" fields[2] "\t" fields[3] "\t" fields[4] "\t" fields[5] "\t" fields[6]
    }
}' "$input_file1" "$input_file2" ${input_file3:+"$input_file3"} | sort -n -k1,1 -k2,2 >> "$output_file"

echo "Merged data saved to $output_file"
