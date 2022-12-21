#!/bin/bash

# create pb-16S-nf metadata file from barcode-name.csv and HiFi read folder

if [ $# -lt 1 ]; then
    echo "usage: make_metadata.sh <barcode_name.csv>"
    exit
fi

echo -e "sample_name\tcondition\tsample_label" > run_metadata.tsv

condition="condition"

# find all fastq and add rows to tsv
readfolder=fastq_results
for fq in $(find ${readfolder} -name "*.fastq.gz" -exec readlink -f {} \;);
do bc=$(basename ${fq} | cut -d "." -f 3)
label=$(cat $1 | grep ${bc} | cut -d "," -f 2)
echo -e "${bc}\t${condition}\t${label}";
done >> run_metadata.tsv
