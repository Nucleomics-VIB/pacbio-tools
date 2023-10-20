#!/bin/bash

# script: run_pb-16s-nf.sh
# run pacbio nf-16s-nf pipeline
# SP@NC, 2023/10/17, v1.1
# depends on modified nextflow.config file as described in:
# https://github.com/PacificBiosciences/pb-16S-nf/issues/39
tooldir="/opt/biotools/pb-16S-nf"
cd ${tooldir}

##################################
# path to input and output folders
##################################

infolder="/mnt/nuc-data/ResearchDev/_NC_Long-Read_DATA/PacBio/pb-16S-nf_data/reads"
outfolder="/mnt/syn_lts/analyses/metagenomics_analysis/16S_analysis/Zymo-SequelIIe-Hifi/results_11smpl_auto"

# create outfolder and put list and metadata files in it
mkdir -p "${outfolder}"

###############################
# experiment related parameters
###############################

readcnt=$(ls ${infolder}/*.fastq.gz | wc -l)
outpfx="run_${readcnt}"
default_group="group1"

# set rarefaction manually in case samples would have too few reads in some samples
# when not set; the rarefaction will be set automatically to include 80% of the samples

# --rarefaction_depth    Rarefaction curve "max-depth" parameter. By default the pipeline
#                        automatically select a cut-off above the minimum of the denoised 
#                        reads for >80% of the samples. This cut-off is stored in a file called
#                        "rarefaction_depth_suggested.txt" file in the results folder
#                        (default: null)

# automatic rarefaction based on 80%
# rarefaction=''

# manual rarefaction
rardepth=10000
rarefaction="--rarefaction_depth ${rardepth}"

# color by (default "condition")
# can be set to other categorical variable if present in the metadata file
colorby="condition"

# use >= 32 cpu for good performance
cpu=64

######################
# filtering parameters
######################

# Minimum number of reads required to keep any ASV: 5
# --min_asv_totalfreq (5)
min_asv_totalfreq=5

# Minimum number of samples required to keep any ASV: 1
# --min_asv_sample (1; 0 to disable)
min_asv_sample=1

###########################
# create sample file (once)
###########################

if [ ! -e "${outfolder}/${outpfx}_samples.tsv" ]; then
(echo -e "sample-id\tabsolute-file-path"
for fq in ${infolder}/*.fastq.gz; do
pfx="$(basename ${fq%.fastq.gz})"
echo -e "${pfx}\t$(readlink -f ${fq})"
done) > "${outfolder}/${outpfx}_samples.tsv"
fi

#############################
# create metadata file (once)
#############################

if [ ! -e "${outfolder}/${outpfx}_metadata.tsv" ]; then
(echo -e "sample_name\tcondition\tbarcode";
for fq in ${infolder}/*.fastq.gz; do
pfx="$(basename ${fq%.fastq.gz})"
bc=$(echo "${fq}" | grep -o -E 'bc[0-9]{4}--bc[0-9]{4}')
echo -e "${pfx}\t${default_group}\t${bc}"
done) > "${outfolder}/${outpfx}_metadata.tsv"
fi

##############
# run nextflow
##############

nextflow run main.nf \
  --input "${outfolder}/${outpfx}_samples.tsv" \
  --metadata "${outfolder}/${outpfx}_metadata.tsv" \
  --outdir "${outfolder}" \
  --dada2_cpu "${cpu}" \
  --vsearch_cpu "${cpu}" \
  --cutadapt_cpu "${cpu}" \
  "${rarefaction}" \
  --min_asv_totalfreq "${min_asv_totalfreq}" \
  --min_asv_sample "${min_asv_sample}" \
  --colorby "${colorby}" \
  -profile docker

#################
# post-processing
#################

# copy results containing symlinks to a full local copy for transfer
rsync -av --copy-links ${outfolder}/results/* ${outfolder}/results_no-links

# add nextflow run_reports and parameters
cp -r ${outfolder}/report ${outfolder}/results_no-links/nextflow_reports
cp ${outfolder}/parameters.txt ${outfolder}/results_no-links/nextflow_reports/
