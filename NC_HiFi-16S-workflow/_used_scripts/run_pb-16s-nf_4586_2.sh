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

# folder with barcoded reads fastq files named as sample-id in ${outpfx}_samples.tsv
infolder="/data/NC_projects/4586_ThessaVanPee_PacBio/run_2/fastq_reads"
barcode_file="/data/NC_projects/4586_ThessaVanPee_PacBio/run_2/Exp4586_2_SMRTlink_barcodefile.csv"

# destination folder for the nextflow outputs
outfolder="/data/NC_projects/4586_ThessaVanPee_PacBio/run_2/pb-16S-nf_10k"

# create outfolder and put sample list and metadata files in it
mkdir -p "${outfolder}"

###############################
# experiment related parameters
###############################

readcnt=$(ls ${infolder}/*.fastq.gz | wc -l)
# outpfx="run_${readcnt}"
outpfx="4586_run2"
default_group="run2"

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
cpu=80

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

##############################
# create metadata file (once)
##############################

if [ ! -e "${outfolder}/../${outpfx}_metadata_nolabels.tsv" ]; then
(echo -e "sample_name\tcondition\tbarcode";
for fq in ${infolder}/*.fastq.gz; do
pfx="$(basename ${fq%.fastq.gz})"
bc=$(echo "${fq}" | grep -o -E 'bc[0-9]{4}--bc[0-9]{4}')
echo -e "${pfx}\t${default_group}\t${bc}"
done) > "${outfolder}/../${outpfx}_metadata_nolabels.tsv"
fi

#####################################
# add labels to metadata file (once)
#####################################

if [ ! -e "${outfolder}/${outpfx}_metadata.tsv" ]; then
# Use awk to process both files together
awk -v FS=',' -v OFS='\t' '
    NR == FNR {
        split($0, csv_columns, ",")
        key = csv_columns[1]
        value = csv_columns[2]
        array[key] = value
        # Print the array during creation for demonstration
        # print "Array[" key "] =", array[key]
        next
    }
    BEGIN {FS = "\t"; OFS="\t"}
    { if (FNR == 1) {print $0,"label"}
      else {
        key = $1
        print $0,array[key]};
    }
' "${barcode_file}" "${outfolder}/../${outpfx}_metadata_nolabels.tsv" \
  > "${outfolder}/${outpfx}_metadata.tsv"
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
  -profile docker 2>&1 | tee ${outfolder}/run_log.txt

#################
# post-processing
#################

# copy results containing symlinks to a full local copy for transfer
final_results="${outfolder}/final_results"
rsync -av --copy-links ${outfolder}/results/* ${final_results}/

# increase reproducibility by storing run info with the final data
# copy the nextflow report folder with runtime info summaries
cp -r ${outfolder}/report ${final_results}/nextflow_reports

# add files containing key info to the new folder
cp ${tooldir}/.nextflow.log ${final_results}/nextflow_reports/nextflow.log
cp ${tooldir}/nextflow.config ${final_results}/nextflow_reports/
cp ${outfolder}/run_log.txt ${final_results}/nextflow_reports/
cp ${outfolder}/parameters.txt ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_samples.tsv ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_metadata.tsv ${final_results}/nextflow_reports/
