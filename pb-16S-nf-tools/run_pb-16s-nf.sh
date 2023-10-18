#!/bin/bash

# script: run_pb-16s-nf.sh
# run pacbio nf-16s-nf pipeline
# SP@NC, 2023/10/17, v1.0

tooldir="/opt/biotools/pb-16S-nf"
cd ${tooldir}

# run on /opt/biotools/pb-16S-nf with input and output data on separate partition
infolder="/mnt/nuc-data/ResearchDev/_NC_Long-Read_DATA/PacBio/pb-16S-nf_data/reads"
outfolder="/mnt/syn_lts/analyses/metagenomics_analysis/16S_analysis/Zymo-SequelIIe-Hifi/results_11smpl_auto"

# set rarefaction manually in case samples would have too few
# when not set; the rarefaction will be set automatically based on, the smallest sample
# rardepth=10000

# color by (default "condition")
# can be set to other categorical variable if present in the metadata file
colorby="condition"

# use >= 32 cpu for good performance
cpu=32

# create outfolder and put list and metadata files in it
mkdir -p ${outfolder}

# experiment related parameters

# count fastq in reads folder
readcnt=$(ls ${infolder}/*.fastq.gz | wc -l)
outpfx="run_${readcnt}"
default_group="group1"

# create sample file
(echo -e "sample-id\tabsolute-file-path"
for fq in ${infolder}/*.fastq.gz; do
pfx=$(basename ${fq%.fastq.gz})
echo -e "${pfx}\t$(readlink -f ${fq})"
done) > ${outfolder}/${outpfx}_samples.tsv

# create metadata file
(echo -e "sample_name\tcondition\tbarcode";
for fq in ${infolder}/*.fastq.gz; do
pfx=$(basename ${fq%.fastq.gz})
bc=$(echo "${fq}" | grep -o -E 'bc[0-9]{4}--bc[0-9]{4}')
echo -e "${pfx}\t${default_group}\t${bc}"
done) > ${outfolder}/${outpfx}_metadata.tsv

# run nextflow
nextflow run main.nf \
  --input ${outfolder}/${outpfx}_samples.tsv \
  --metadata ${outfolder}/${outpfx}_metadata.tsv \
  --outdir ${outfolder} \
  --dada2_cpu ${cpu} \
  --vsearch_cpu ${cpu} \
  --cutadapt_cpu ${cpu} \
  --colorby  ${colorby} \
  -profile docker

# --rarefaction_depth ${rardepth} \

# copy results containing symlinks to a full local copy
rsync -av --copy-links ${outfolder}/results/* ${outfolder}/results_no-links

# add nextflow run_reports and parameters
cp -r ${tooldir}/report_/${outfolder} ${outfolder}/results_no-links/nextflow_reports
cp ${outfolder}/parameters.txt ${outfolder}/results_no-links/nextflow_reports/
