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

version="2024-06-14; 1.1.0"

DOCKER_IMAGE="kinnex_16s_tools:1.0.0"

# taken care of by internal script in the docker run_in_conda.sh
# added to the image with at the end of the Dockerfile:
# ENTRYPOINT ["./run_in_env.sh"]
#
# myenv="Kinnex_16S_decat_demux_env"
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

mkdir -p ${outfolder}

# redirect all outputs to a log file
cat /dev/null > ${outfolder}/runlog.txt
exec &> >(tee -a ${outfolder}/runlog.txt)

########## FUNCTIONS ###########

function CopyRunData {
local flag_file="${outfolder}/${inputs}/CopyRunData_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "CopyRunData: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${inputs}"

echo -e "\n# Copying RUN data locally"

# Check if the adapter folder exists
if [ -d "${runfolder}/${adapterfolder}" ]; then
    cp -r "${runfolder}/${adapterfolder}" "${outfolder}/${inputs}"
else
    echo "Adapter folder not found: ${runfolder}/${adapterfolder}"
    return 1 # Exit the function with an error status
fi

# Check if the sample sheet exists
if [ -f "${runfolder}/${samplesheet}" ]; then
    cp "${runfolder}/${samplesheet}" "${outfolder}/${inputs}/"
else
    echo "Sample sheet not found: ${runfolder}/${samplesheet}"
    return 1 # Exit the function with an error status
fi

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  touch "$flag_file"
fi

}

function SkeraSplit {
local flag_file="${outfolder}/${skera_results}/SkeraSplit_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "SkeraSplit: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${skera_results}"

echo -e "\n# Running Skera de-concatenation"

# -u $(id -u):$(id -g)
SKERA_CMD="docker run --rm -u $(id -u):$(id -g) -v $PWD:$PWD ${DOCKER_IMAGE} skera"

cmd="${SKERA_CMD} split \
  ${outfolder}/${inputs}/${adapterfolder}/${movie}.hifi_reads.${adapterfolder}.bam \
  barcode_files/MAS-Seq_Adapter_v2/mas12_primers.fasta \
  ${outfolder}/${skera_results}/${movie}.skera.bam \
  --num-threads ${nthr_skera} \
  --log-level ${log_skera} \
  --log-file ${outfolder}/${skera_results}/skera_run-log.txt"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  touch "$flag_file"
fi

}

function Lima {
local flag_file="${outfolder}/${lima_results}/Lima_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "Lima: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${lima_results}"

echo -e "\n# Running Lima demultiplexing"

LIMA_CMD="docker run --rm -u $(id -u):$(id -g) -v $PWD:$PWD ${DOCKER_IMAGE} lima"

cmd="${LIMA_CMD} \
  ${outfolder}/${skera_results}/${movie}.skera.bam \
  barcode_files/Kinnex16S_384plex_primers/Kinnex16S_384plex_primers.fasta \
  ${outfolder}/${lima_results}/HiFi.bam \
  --hifi-preset ASYMMETRIC \
  --split-named \
  --biosample-csv ${outfolder}/${inputs}/${samplesheet} \
  --split-subdirs \
  --num-threads ${nthr_lima} \
  --log-level ${log_lima} \
  --log-file ${outfolder}/${lima_results}/lima_run-log.txt"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  touch "$flag_file"
fi

}

function bam2fastq {
local flag_file="${outfolder}/${lima_results}/bam2fastq_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "bam2fastq: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${fastq_results}"
cat /dev/null > ${outfolder}/job.list

echo -e "\n# Preparing job list from all lima BAM files"

# prepare a list for parallel processing across all BAM files
for bam in $(find ${outfolder}/${lima_results} -name "*.bam"); do
# rename sample from samplesheet 'Bio Sample'
pfx=$(basename ${bam%.bam})
bcpair=${pfx#HiFi.}
biosample=$(grep ${bcpair} ${outfolder}/${inputs}/${samplesheet} | \
  dos2unix | cut -d, -f 2 | tr -d "\n")

# add command to job.list
echo "bam2fastq \
    ${bam} \
    --output ${outfolder}/${fastq_results}/${biosample} \
    --num-threads ${nthr_bam2fastq}" >> ${outfolder}/job.list
done

# run job.list in parallel from the docker image
XARGS_CMD="cat ${outfolder}/job.list | xargs -P ${par_bam2fastq} -I {} bash -c '{}'"

echo -e "\n# Executing job list in parallel batches"

echo "# ${XARGS_CMD}"
eval ${XARGS_CMD}

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
  touch "$flag_file"
fi

}

function BundleResults {
local flag_file="${outfolder}/BundleResults_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "BundleResults: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${outfolder}/${final_results}"

echo -e "\n# Copying files to final_result folder for transfer"

# copy run_QC from RUN folder
cp ${runfolder}/*.pdf ${outfolder}/${final_results}/

# copy Zymo control PDF and README.txt
cp -r info ${outfolder}/${final_results}/

cp ${outfolder}/${inputs}/${samplesheet} ${outfolder}/${final_results}/
cp ${outfolder}/${skera_results}/${movie}.skera.summary.csv ${outfolder}/${final_results}/skera.summary.csv
cp ${outfolder}/${lima_results}/HiFi.lima.{"counts","summary"} ${outfolder}/${final_results}/

# create symlink for fastq to save room
# the symlink will be archived as source folder using tar -h /--dereference
ln -s ${outfolder}/${fastq_results} ${outfolder}/${final_results}/

echo -e "# Creating barcode QC report"
projectnum=$(echo ${samplesheet} | cut -d "_" -f 1 | tr -d "\n")

PLOT_CMD="docker run --rm -u $(id -u):$(id -g) -v $PWD:$PWD ${DOCKER_IMAGE} scripts/barcode_QC_Kinnex.sh"

cmd="${PLOT_CMD} \
  -i ${outfolder}/${final_results}/HiFi.lima.counts \
  -o ${outfolder} \
  -r /app/scripts/barcode_QC_Kinnex.Rmd \
  -m ${mincnt} \
  -f ${qc_format} \
  -p ${projectnum} \
  -s ${outfolder}/${inputs}/${samplesheet}"

echo "# ${cmd}"
eval ${cmd} && cp ${outfolder}/barcode_QC_Kinnex.${qc_format} ${outfolder}/${final_results}/

# Write the flag file upon successful completion
exit_code=$?
if [[ $exit_code -eq 0 ]]; then
   touch "$flag_file"
fi

}

function createArchive {
local flag_file="${outfolder}/Archive_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "# create barcode plots
${flag_file}" ]; then
    echo "createArchive: already done."
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


############### PIPELINE ###############

time CopyRunData

time SkeraSplit

time Lima

time bam2fastq

time BundleResults

time createArchive
