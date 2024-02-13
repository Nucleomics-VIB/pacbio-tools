#!/bin/bash

# pb-16S-nf_make_metadata_group.sh
# create pb-16S-nf metadata file from barcode-name.csv and HiFi read folder
#
# Stephane Plaisance (VIB-NC) 2023/10/20; v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB

while getopts ":c:r:" opt; do
  case $opt in
    c) barcode_file="$OPTARG";;
    r) readfolder="$OPTARG";;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      echo "Usage: $0 [-c <barcode_file>] [-r <readfolder>] [-p <pos>]"
      exit 1
      ;;
  esac
done

# Set default values
if [ -z "$readfolder" ]; then
  readfolder="fastq_reads"
fi

if [ -z "$barcode_file" ]; then
  barcode_file="Barcodefile.csv"
fi

echo -e "sample_name\tcondition\tsample_label" > run_metadata.tsv

# Find all fastq and add rows to tsv
for fq in $(find "$readfolder" -name "*.fastq.gz" -exec readlink -f {} \;); do
    # Extract the barcode from the full name at the specified position
    bc=$(basename "$fq" | cut -d "." -f 1)
    # get group from column3 of the barcode file (added manually)
    condition=$(cat "$barcode_file" | grep "$bc" | cut -d "," -f 3 | tr -d '\r')
    # Get user label from the barcode to sample file
    label=$(cat "$barcode_file" | grep "$bc" | cut -d "," -f 2)
    # Write both to the metadata file
    echo -e "${bc}\t${condition}\t${label}";
done >> run_metadata.tsv
