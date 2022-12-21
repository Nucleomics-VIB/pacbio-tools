#!/bin/bash

# create pb-16S-nf run_samples.tsv file from HiFi read folder

echo -e "sample-id\tabsolute-file-path" > run_samples.tsv

# find all fastq and add rows to tsv
readfolder=${1:-fastq_results}

for fq in $(find ${readfolder} -name "*.fastq.gz" -exec readlink -f {} \;);
do bc=$(basename ${fq} | cut -d "." -f 3)
echo -e "${bc}\t${fq}";
done >> run_samples.tsv
