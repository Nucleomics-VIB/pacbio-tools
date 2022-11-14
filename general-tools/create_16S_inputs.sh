#!/bin/bash

# script: create_16S_inputs.sh

# create samples.tsvand metadata.tsv for pb-16S-nf
# the metadata file needs be manually edited to change control samples to 'Control'

if [ $# -lt 2 ]; then
    echo "# requires read folder and barcode.csv arguments"
    exit 1
fi

readfolder=$1
barcodes=$2

##################
# create samples.tsv
##################

# create sample.tsv for nextflow pipeline
# readfolder=fastq_reads
cat /dev/null > bc2samples.tsv
for fq in $(find ${readfolder} -name "*.fastq.gz"| sort -k 1V,1); do
pfx=$(basename ${fq} ".fastq.gz");
echo -e ${pfx}"\t"$(readlink -f ${fq}) >> bc2samples.tsv;
done

# it should be matches with a metadata.tsv file
# barcodes="Exp4285_SMRTlink_barcodefile.csv"
cat /dev/null > bc2names.tsv
cat ${barcodes} | sed -e '1d'| sed -e 's:,:\t:' | sort -k 1V,1 | tr -d '\r' >> bc2names.tsv

# join and keep columns 2 and 3
echo -e "sample-id\tabsolute-filepath" > samples.tsv
join -t $'\t'  -a1 -a2 -e 1 -o auto bc2names.tsv bc2samples.tsv | cut -f 2,3 >> samples.tsv


###################
# create metadata.tsv
###################

echo -e "sample_name\tcondition" > metadata.tsv
awk 'BEGIN{IFS="\t";OFS="\t"}{print $2, "Sample"}'  bc2names.tsv >> metadata.tsv

#########
# cleanup #
#########

rm bc2*