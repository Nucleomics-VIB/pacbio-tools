#!/usr/bin/env bash

# script: Kinnex_16S_decat_demux.sh
# run skera and lima on a Kinnex 16S RUN
#
# Stephane Plaisance - VIB-NC 2024-06-03 v1.0
# small edits in the header below: v1.0.1
# rewritten to improve file structure: v1.1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements:
# conda env: Kinnex_16S_decat_demux_env (installed from conda_env_setup.yaml)
# => conda env create -f conda_env_setup.yaml
# config.yaml (edited and pointing to existing files)
# yq (to read the yaml config file into bash variables)
# PacBio barcode files copied to barcode_files)
# pigz for archiving speedup
# a BAM file resulting from a Kinnez 16S run
# a samplesheet linking barcode pairs to sample names (custom made)
# All parameters have been externalised from the code and are listed in config.yaml

version="2024-06-25; 1.0.0"

DOCKER_IMAGE="pb-16s-nf-docker:1.0.0"

# taken care of by internal script in the docker run_in_conda.sh
# added to the image with at the end of the Dockerfile:
# ENTRYPOINT ["./run_in_env.sh"]
#
# myenv="pb-16s-nf_env"
# source /etc/profile.d/conda.sh
# conda activate ${myenv} || \
#   ( echo "# the conda environment ${myenv} was not found on this machine" ;
#     echo "# please read the top part of the script!" \
#     && exit 1 )

# create tmp folder for Rmd knitting
workdir=$PWD
mkdir -p ${workdir}/tmp

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
    echo "config.yaml file not found. Please create the config.yaml file."
    exit 1
fi

# Load variables from config.yaml
# replaces the yq version because yq was difficult to install in docker
# eval $(yq e '. as $item ireduce ("";  . + "export " + ($item | to_entries | .[] | .key + "=\"" + .value + "\" "))' config.yaml)

while IFS= read -r line; do
    # Skip lines starting with # or empty lines
    if [[ "$line" =~ ^#|^$ ]]; then
        continue
    fi

    # Split the line into key and value
    key=$(echo "$line" | cut -d':' -f1)
    value=$(echo "$line" | cut -d':' -f2-)

    # Remove any leading or trailing whitespace from the key and value
    key=${key##* }
    key=${key% *}
    value=${value##* }
    value=${value% *}

    # Remove double-quotes from the value
    value=${value//\"/}

    # Assign the value to the Bash variable
    declare "$key"="$value"
done <  config.yaml

outfolder=${workdir}/${outfolder}
mkdir -p ${outfolder}

# redirect all outputs to a log file
cat /dev/null > ${outfolder}/runlog.txt
exec &> >(tee -a ${outfolder}/runlog.txt)

########## FUNCTIONS ###########

###########################
# copy data (once)
###########################

function copy_data {

local flag_file="${outfolder}/${inputs}/01_copy_data_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "copy_data: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${inputs}"

# Check if the barcode file exists (Exp4767_SMRTLink_Barcodefile.csv)
if [ -f "${barcodefile}" ]; then
    echo -e "\n# Copying barcode file locally"
    cp "${barcodefile}" "${outfolder}/${inputs}/"
    export projnum=$(basename ${barcodefile} | cut -d '_' -f 1)
else
    echo "barcode file not found: ${barcodefile}"
    return 1 # Exit the function with an error status
fi

# Check if the adapter folder exists
if [ -d "${fastqfiles}" ]; then
    echo -e "\n# Copying fastq data locally"
    cp -r "${fastqfiles}" "${outfolder}/${inputs}"
    readcnt=$(ls ${outfolder}/${inputs}/fastq_results/*.fastq.gz | wc -l)
    export outpfx="${projnum}_${readcnt}"
else
    echo "fastq folder not found: ${fastqfiles}"
    return 1 # Exit the function with an error status
fi

echo -e "\n# Data will be saved with prefix: ${outpfx}"

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  touch "$flag_file"
fi

}

###########################
# create sample file (once)
###########################

function create_samplefile {

local flag_file="${outfolder}/02_create_samplefile_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "create_samplefile: already done."
    return 0 # Exit the function successfully
fi

# Count the number of fastq files
fastqcnt=$(ls ${outfolder}/${inputs}/fastq_results/*.fastq.gz 2>/dev/null | wc -l)

if [[ ${fastqcnt} -gt 0 ]]; then
    echo "# found ${fastqcnt} fastq files in ${outfolder}/${inputs}/fastq_results/"

    # list the fastq files to ${outpfx}_sample.tsv
    (echo -e "sample-id\tabsolute-file-path"
    (for fq in ${outfolder}/${inputs}/fastq_results/*.fastq.gz; do
        pfx="$(basename ${fq%.fastq.gz})"
        echo -e "${pfx}\t$(readlink -f ${fq})"
    done
    ) | sort -k 1V,1 ) > "${outfolder}/${outpfx}_samples.tsv"

    # Write the flag file upon successful completion
    exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
       touch "$flag_file"
    fi
else
    echo "# no fastq files found in path: ${outfolder}/${inputs}/fastq_results/"
    exit 1 # Exit the function with an error status
fi

}

##############################
# create metadata file (once)
##############################

function create_metafile {

local flag_file="${outfolder}/03_create_metafile_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "create_metafile: already done."
    return 0 # Exit the function successfully
fi

if [ ! -e "${outfolder}/${outpfx}_metadata.tsv" ]; then
(echo -e "sample_name\tid\tlabel\tmeta1\tmeta2";
(for fq in ${outfolder}/${inputs}/fastq_results/*.fastq.gz; do

# get full label
name=$(basename "$fq" | cut -d "." -f 1)

# add id
id=$(echo "${name}" | cut -d "_" -f 1 | tr -d '\r')

# add user provided label
label=$(echo "${name}" | cut -d '_' --complement -f 1 | tr -d '\r')
meta1=$(echo "${name}" | cut -d "_" -f 2 | tr -d '\r')
meta2=$(echo "${name}" | cut -d "_" -f 3 | tr -d '\r')

echo -e "${name}\t${id}\t${label}\t${meta1}\t${meta2}"

done) | sort -k 1V,1 ) > "${outfolder}/${outpfx}_metadata.tsv"
fi

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
   touch "$flag_file"
fi

}

##############
# run nextflow
##############

function run_nextflow {

local flag_file="${outfolder}/04_run_nextflow_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "run_nextflow: already done."
    return 0 # Exit the function successfully
fi

# -u $(id -u):$(id -g)
docker_cmd="docker run --rm -v ${outfolder}:${outfolder} ${DOCKER_IMAGE}"

cmd="${docker_cmd} nextflow run pb-16S-nf/main.nf \
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
  --downsample "${subsample}" \
  --colorby "${colorby}" \
  --dada2_cpu "${dcpu}" \
  --vsearch_cpu "${vcpu}" \
  --cutadapt_cpu "${ccpu}" \
  --publish_dir_mode "${pmod}" \
  -profile docker 2>&1 | tee ${outfolder}/run_log.txt"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
   touch "$flag_file"
fi

}

#################
# post-processing
#################

function bundle_results {

local flag_file="${outfolder}/05_bundle_results_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "bundle_results: already done."
    return 0 # Exit the function successfully
fi

final_results="${outfolder}/final_results"

echo "# needs edits"
exit 0

# obsolete with --publish_dir_mode "copy"
# copy results containing symlinks to a full local copy for transfer
#final_results="${outfolder}/final_results"
#rsync -av --copy-links ${outfolder}/results/* ${final_results}/

# increase reproducibility by storing run info with the final data
# copy the nextflow report folder with runtime info summaries
cp -r ${outfolder}/report ${final_results}/nextflow_reports

# add files containing key info to the nextflow_reports folder
cp ${tooldir}/.nextflow.log ${final_results}/nextflow_reports/nextflow.log
cp ${tooldir}/nextflow.config ${final_results}/nextflow_reports/
cp ${outfolder}/run_log.txt ${final_results}/nextflow_reports/
cp ${outfolder}/parameters.txt ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_samples.tsv ${final_results}/nextflow_reports/
cp ${outfolder}/${outpfx}_metadata.tsv ${final_results}/nextflow_reports/

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
   touch "$flag_file"
fi

}

function create_archive {
local flag_file="${outfolder}/06_create_archive_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "# create barcode plots
${flag_file}" ]; then
    echo "create_archive: already done."
    return 0 # Exit the function successfully
fi

echo -e "\n# Creating TGZ archive of ${final_results} and its md5sum"

thr=8
pfx="$(echo ${samplesheet} | cut -d '_' -f 1 | tr -d '\n')_archive"

cmd="docker run --rm -u $(id -u):$(id -g) -v $PWD:$PWD ${DOCKER_IMAGE} /app/create_archive.sh ${outfolder} ${final_results} ${thr} ${pfx}"

echo "# ${cmd}"
eval ${cmd}

# write flag if checksum is OK
if grep -q "OK" "${outfolder}/${pfx}.tgz_md5-check.txt"; then
    # Write the flag file upon successful completion
    touch "$flag_file"
else
    echo "Flag file not created. Verification failed."
fi
}

time copy_data

time create_samplefile

time create_metafile

time run_nextflow

exit 0
time BundleResults
exit 0
time createArchive
