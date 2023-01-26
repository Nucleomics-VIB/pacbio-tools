#!/bin/bash

# pb-16S-nf_make_samples.sh
# create pb-16S-nf run_samples.tsv file from HiFi read folder
# remove carriage return from readlink output

echo -e "sample-id\tabsolute-file-path" > run_samples.tsv

# find all fastq and add rows to tsv
readfolder=${1:-fastq_results}

# read files are named like
#  m64279e_221217_093107.hifi_reads.bc1024--bc1044.fastq.gz

# substring to keep (3 for Sequel original file)
# pos=3
# for custom read names like bc1024--bc1044.fastq.gz
pos=1

for fq in $(find ${readfolder} -name "*.fastq.gz" -exec readlink -f {} \;);
do bc=$(basename ${fq} | cut -d "." -f 3)
echo -e "${bc}\t${fq}";
done | tr -d '\r' >> run_samples.tsv
