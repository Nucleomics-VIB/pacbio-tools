#!/bin/bash

# script: MergeLimaCounts.sh
# Usage: ./MergeLimaCounts.sh <input_file1> <input_file2>
# Description: Merge and aggregate Kinnex Lima TSV files from two runs

# This script merges two TSV files containing Lima sequencing data based on
# IdxFirst and IdxCombined columns.
# It aggregates counts and calculates weighted mean scores.
# Author: SP@NC (AI)
# Created: 2025-02-04
# Version: 1.0

if [ $# -ne 2 ]; then
    echo "Usage: $0 <input_file1> <input_file2>"
    exit 1
fi

input_file1="$1"
input_file2="$2"
output_file="merged_output.tsv"

# Write header to output file
head -n 1 "$input_file1" > "$output_file"

# Process and merge data
awk -F'\t' '
function safe_div(a, b) {
    return (b != 0) ? a / b : 0
}

FNR == 1 { next } # Skip header row for both files

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
}' "$input_file1" "$input_file2" | sort -n -k1,1 -k2,2 >> "$output_file"

echo "Merged data saved to $output_file"
