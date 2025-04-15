#!/bin/bash

# script: MergeFilterLimaCounts.sh
#
# Description: Merge and filter Kinnex Lima TSV files from two or three runs and a csv barcode file
# Usage: ./MergeLimaCounts.sh -1 <input_file1> -2 <input_file2> [-3 <input_file3 (optional)>]  [-b <barcode2name.csv>] [-o <output_file>]
# This script merges two or three TSV files containing Lima sequencing data based on
# IdxFirst and IdxCombined columns.
# It aggregates counts and calculates weighted mean scores (sum of scores / #runs).
# It saves the aggregated counts for all barcode pairs found in the barcode file
# Author: SP@NC (+AI)
# Created: 2025-02-04
# Version: 1.4 - Added barcode filtering with barcode2name.csv file

# Default output file name
output_file="merged_output.tsv"
barcode_file=""

# Function to display usage
usage() {
    echo "Usage: $0 -1 <input_file1> -2 <input_file2> [-3 <input_file3 (optional)>] [-o <output_file>] [-b <barcode2name.csv>]"
    echo "  -1 <input_file1>: First input TSV file (required)"
    echo "  -2 <input_file2>: Second input TSV file (required)"
    echo "  -3 <input_file3>: Third input TSV file (optional)"
    echo "  -b <barcode2name.csv>: CSV file mapping barcodes to sample names (optional)"
    echo "  -o <output_file>: Output file name (default: merged_output.tsv)"
    exit 1
}

# Parse command line options
while getopts ":1:2:3:o:b:" opt; do
    case $opt in
        1) input_file1="$OPTARG" ;;
        2) input_file2="$OPTARG" ;;
        3) input_file3="$OPTARG" ;;
        b) barcode_file="$OPTARG" ;;
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

# Check if barcode file exists if provided
if [ -n "$barcode_file" ] && [ ! -f "$barcode_file" ]; then
    echo "Error: Barcode file '$barcode_file' does not exist."
    exit 1
fi

# Write header to output file
head -n 1 "$input_file1" > "$output_file"

# Process and merge data
if [ -z "$barcode_file" ]; then
    # Process without barcode filtering
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
else
    # Process with barcode filtering
    awk -F'\t' -v barcode_file="$barcode_file" '
    function safe_div(a, b) {
        return (b != 0) ? a / b : 0
    }
    
    BEGIN {
        # Read barcode file and create mapping
        FS_CSV = ","
        while ((getline line < barcode_file) > 0) {
            if (index(line, "Barcode,") == 1) continue; # Skip header
            
            split(line, parts, FS_CSV)
            barcode = parts[1]
            gsub(/[\r\n]/, "", barcode) # Remove carriage returns/linefeeds
            valid_barcodes[barcode] = 1
        }
        close(barcode_file)
        FS = "\t" # Reset field separator for main processing
    }

    FNR == 1 { next } # Skip header row for all files

    {
        # Generate barcode key for matching against CSV
        barcode_key = $3 "--" $4
        
        # Skip "Not Barcoded" rows or any row where either barcode part is "none"
        if ($3 == "none" || $4 == "none" || barcode_key == "Not Barcoded") {
            next
        }
        
        # Skip if barcode not in our valid list
        if (!(barcode_key in valid_barcodes)) {
            next
        }
        
        # Process matching rows
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
fi

echo "Merged data saved to $output_file"