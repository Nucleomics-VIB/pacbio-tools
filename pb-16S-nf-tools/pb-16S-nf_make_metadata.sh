#!/bin/bash

# pb-16S-nf_make_metadata.sh
# create pb-16S-nf metadata file from barcode-name.csv and HiFi read folder

if [ $# -lt 1 ]; then
    echo "usage: make_metadata.sh <barcode_name.csv>"
    exit
fi

echo -e "sample_name\tcondition\tsample_label" > run_metadata.tsv

condition="condition"

# find all fastq and add rows to tsv
readfolder=${2:-fastq_results}

# read files are named like
#  m64279e_221217_093107.hifi_reads.bc1024--bc1044.fastq.gz

for fq in $(find ${readfolder} -name "*.fastq.gz" -exec readlink -f {} \;);
do 
# isolate bc1024--bc1044 from the full name
bc=$(basename ${fq} | cut -d "." -f 3)
# get user label from sequel sample to barcode file
label=$(cat $1 | grep ${bc} | cut -d "," -f 2)
# write both to the metadata file
echo -e "${bc}\t${condition}\t${label}";
done >> run_metadata.tsv
