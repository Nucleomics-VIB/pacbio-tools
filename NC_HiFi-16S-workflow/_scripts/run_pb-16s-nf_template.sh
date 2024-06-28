#!/bin/bash

# script: run_pb-16s-nf.sh
# run pacbio nf-16s-nf pipeline
# SP@NC, 2023/10/23, v1.2
# depends on modified nextflow.config file as described in:
# https://github.com/PacificBiosciences/pb-16S-nf/issues/39

tooldir="/opt/biotools/pb-16S-nf"
cd ${tooldir}

##################################
# path to input and output folders
##################################

# folder with barcoded reads fastq files named as sample-id in ${outpfx}_samples.tsv
infolder="<...READPATH...>"

# destination folder for the nextflow outputs
outfolder="<...DESTPATH...>"

# create outfolder and put sample list and metadata files in it
mkdir -p "${outfolder}"

###############################
# experiment related parameters
###############################

readcnt=$(ls ${infolder}/*.fastq.gz | wc -l)
outpfx="run_${readcnt}"
default_group="group1"

######################
# amplicon parameters
######################

#  --front_p   Forward primer sequence. Default to F27. (default: AGRGTTYGATYMTGGCTCAG)
#  --adapter_p Reverse primer sequence. Default to R1492. (default: AAGTCGTAACAAGGTARCY)
#  --min_len   Minimum length of sequences to keep (default: 1000)
#  --max_len   Maximum length of sequences to keep (default: 1600)

fprimer="AGRGTTYGATYMTGGCTCAG"
rprimer="AAGTCGTAACAAGGTARCY"

minl=1000
maxl=1600

# --filterQ  Filter input reads above this Q value (default: 20).
readminq=20

#################
# DADA parameters
#################

#  --max_ee  DADA2 max_EE parameter. Reads with number of expected errors higher than
#            this value will be discarded (default: 2)
maxee=2

#  --minQ  DADA2 minQ parameter. Reads with any base lower than this score
#          will be removed (default: 0)
minq=0

# --pooling_method    QIIME 2 pooling method for DADA2 denoise see QIIME 2
#   documentation for more details (default: "pseudo", alternative: "independent")
poolm="pseudo"

###############
# ASV filtering
###############

# Minimum number of reads required to keep any ASV: 5
# --min_asv_totalfreq (5)
min_asv_totalfreq=5

# Minimum number of samples required to keep any ASV: 1
# --min_asv_sample (1; 0 to disable)
min_asv_sample=1

####################
# VSEARCH parameters
####################

# --maxreject  max-reject parameter for VSEARCH taxonomy classification method in QIIME 2
#              (default: 100)
# --maxaccept  max-accept parameter for VSEARCH taxonomy classification method in QIIME 2
#              (default: 100)
maxrej=100
maxacc=100

# --vsearch_identity    Minimum identity to be considered as hit (default 0.97)
vsid="0.97"

##############
# publish mode
##############

# --publish_dir_mode    Outputs mode based on Nextflow "publishDir" directive. Specify "copy"
#                       if requires hard copies. (default: symlink)
pmod="copy"

# set rarefaction manually in case samples would have too few reads in some samples
# when not set; the rarefaction will be set automatically to include 80% of the samples

# --rarefaction_depth    Rarefaction curve "max-depth" parameter. By default the pipeline
#                        automatically select a cut-off above the minimum of the denoised
#                        reads for >80% of the samples. This cut-off is stored in a file called
#                        "rarefaction_depth_suggested.txt" file in the results folder
#                        (default: null)

# automatic rarefaction based on 80%
# rarefaction=""

# manual rarefaction
rardepth=10000
rarefaction="--rarefaction_depth ${rardepth}"

# color by (default "condition")
# can be set to other categorical variable if present in the metadata file
colorby="condition"

# use >= 32 cpu for good performance
ccpu=64
dcpu=64
vcpu=64

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

##############################
# create metadata file (once)
##############################

if [ ! -e "${outfolder}/${outpfx}_metadata.tsv" ]; then
(echo -e "sample_name\tcondition\tlabel\tgroup";
for fq in ${infolder}/*.fastq.gz; do

# get barcode
bc=$(basename "$fq" | cut -d "." -f 1)

# add condition=group if provided in the Barcodefile (col#3)
grp=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 3 | tr -d '\r')
# set grp to ${default_group} if undef
if [ -z "${grp}" ]; then
  grp="${default_group}"
fi

# add user provided label
label=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 2)

# add extra metadata column
meta2=$(cat "${barcode_file}" | grep "${bc}" | cut -d "," -f 4 | tr -d '\r')
# set meta2 to na if undef
if [ -z "${meta2}" ]; then
  meta2="na"
fi

echo -e "${bc}\t${grp}\t${label}\t${meta2}"

done) > "${outfolder}/../${outpfx}_metadata.tsv" && \
cp  "${outfolder}/../${outpfx}_metadata.tsv"  "${outfolder}/${outpfx}_metadata.tsv"
fi


##############
# run nextflow
##############

nextflow run main.nf \
  --input "${outfolder}/${outpfx}_samples.tsv" \
  --metadata "${outfolder}/${outpfx}_metadata.tsv" \
  --outdir "${outfolder}" \
  --front_p "${fprimer}" \
  --adapter_p "${rprimer}" \
  --min_len "${minl}" \
  --max_len "${maxl}" \
  --filterQ "${readminq}" \
  --pooling_method "${poolm}" \
  --max_ee "${maxee}" \
  --minQ "${minq}"\
  --maxreject "${maxrej}" \
  --maxaccept "${maxacc}" \
  --min_asv_totalfreq "${min_asv_totalfreq}" \
  --min_asv_sample "${min_asv_sample}" \
  --vsearch_identity "${vsid}" \
  ${rarefaction} \
  --colorby "${colorby}" \
  --dada2_cpu "${dcpu}" \
  --vsearch_cpu "${vcpu}" \
  --cutadapt_cpu "${ccpu}" \
  --publish_dir_mode "${pmod}" \
  -profile docker 2>&1 | tee ${outfolder}/run_log.txt

#################
# post-processing
#################

final_results="${outfolder}/results"

# obsolete with --publish_dir_mode "copy"
# copy results containing symlinks to a full local copy for transfer
#final_results="${outfolder}/final_results"
#rsync -av --copy-links ${outfolder}/results/* ${final_results}/

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
