#!/bin/bash

# script: run_pb-16s-nf.sh
# run pacbio nf-16s-nf pipeline
# SP@NC, 2025/02/18, v1.2
# depends on modified nextflow.config file as described in:
# https://github.com/PacificBiosciences/pb-16S-nf/issues/39
tooldir="/opt/biotools/pb-16S-nf"
cd "${tooldir}" || exit 1

##################################
# path to input and output folders
##################################

# folder with barcoded reads fastq files named as sample-id in ${outpfx}_samples.tsv
basefolder="/data/NC_projects/<PRJ>"
infolder="${basefolder}/fastq_reads"
barcode_file="${basefolder}/<PRJ>_SMRTLink_Barcodefile.csv"

# destination folder for the nextflow outputs
outfolder="${basefolder}/pb-16S-nf_kinnex-20k"

# create outfolder and put sample list and metadata files in it
mkdir -p "${outfolder}/tmp"

###############################
# experiment related parameters
###############################

readcnt=$(ls ${infolder}/*.fastq.gz | wc -l)
outpfx="run_${readcnt}"
default_group="group1"

####################################################
# many default arguments have momved to config.yaml
####################################################

echo "# processing ${readcnt} fastq files"

# set rarefaction manually in case samples would have too few reads in some samples
# when not set; the rarefaction will be set automatically to include 80% of the samples

# --rarefaction_depth    Rarefaction curve "max-depth" parameter. By default the pipeline
#                        automatically select a cut-off above the minimum of the denoised
#                        reads for >80% of the samples. This cut-off is stored in a file called
#                        "rarefaction_depth_suggested.txt" file in the results folder
#                        (default: null)

# automatic rarefaction based on 80%
rarefaction=''

# uncomment for manual rarefaction
#rardepth=10000
#rarefaction="--rarefaction_depth ${rardepth}"

# color by (default "condition")
# can be set to other categorical variable if present in the metadata file
colorby="smplgrp"

# use >= 32 cpu for good performance
cpu=84

######################
# filtering parameters
######################

# Minimum number of reads required to keep any ASV: 5
# --min_asv_totalfreq (5)
min_asv_totalfreq=5

# Minimum number of samples required to keep any ASV: 1
# --min_asv_sample (1; 0 to disable)
min_asv_sample=1

# subsample 20000 reads for large samples
subsample=20000

###########################
# create sample file (once)
###########################

if [ ! -e "${outfolder}/${outpfx}_samples.tsv" ]; then
(echo -e "sample-id\tabsolute-file-path"
for fq in ${infolder}/*.fastq.gz; do
pfx="$(basename ${fq%.fastq.gz})"
echo -e "${pfx}\t$(readlink -f ${fq})"
done) > "${outfolder}/../${outpfx}_samples.tsv" && \
cp "${outfolder}/../${outpfx}_samples.tsv" "${outfolder}/${outpfx}_samples.tsv"
fi

##############################
# create metadata file (once)
##############################

if [ ! -e "${outfolder}/${outpfx}_metadata.tsv" ]; then
(echo -e "sample_name\tsmplid\tlabel\tsmplgrp";
for fq in ${infolder}/*.fastq.gz; do
bc=$(basename "$fq" | cut -d "." -f 1)
# smplid label grpid
smplid=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 3 | tr -d '\r')
label=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 4 | tr -d '\r')
smplgrp=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 5 | tr -d '\r')
echo -e "${bc}\t${smplid}\t${label}\t${smplgrp}"
done) > "${outfolder}/../${outpfx}_metadata.tsv" && \
cp  "${outfolder}/../${outpfx}_metadata.tsv"  "${outfolder}/${outpfx}_metadata.tsv"
fi

##############
# run nextflow
##############

TMPDIR="${outfolder}/tmp" NXF_WORK="${basefolder}/work" nextflow run main.nf \
  --input "${outfolder}/${outpfx}_samples.tsv" \
  --metadata "${outfolder}/${outpfx}_metadata.tsv" \
  --outdir "${outfolder}" \
  --dada2_cpu "${cpu}" \
  --vsearch_cpu "${cpu}" \
  --cutadapt_cpu "${cpu}" \
  "${rarefaction}" \
  --downsample "${subsample}" \
  --min_asv_totalfreq "${min_asv_totalfreq}" \
  --min_asv_sample "${min_asv_sample}" \
  --colorby "${colorby}" \
  -profile docker \
  -c extra.config 2>&1 | tee ${outfolder}/run_log.txt

#################
# post-processing
#################

echo "# copying results to the final_results folder"

# copy results containing symlinks to a full local copy for transfer
final_results="${outfolder}/final_results"
rsync -av --copy-links ${outfolder}/results/* ${final_results}/
rsync -av --copy-links ${outfolder}/dada2 ${final_results}

# increase reproducibility by storing run info with the final data
# copy the nextflow report folder with runtime info summaries
cp -r ${outfolder}/report ${final_results}/nextflow_reports

# add files containing key info to the nextflow_reports folder
cp ${tooldir}/.nextflow.log ${final_results}/nextflow_reports/nextflow.log
cp ${tooldir}/main.nf ${final_results}/nextflow_reports/
cp ${tooldir}/nextflow.config ${final_results}/nextflow_reports/
cp ${tooldir}/extra.config ${final_results}/nextflow_reports/
cp ${outfolder}/run_log.txt ${final_results}/nextflow_reports/
cp ${outfolder}/parameters.txt ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_samples.tsv ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_metadata.tsv ${final_results}/nextflow_reports/
