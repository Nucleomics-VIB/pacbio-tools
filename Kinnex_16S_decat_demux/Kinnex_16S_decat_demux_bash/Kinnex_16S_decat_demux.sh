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

myenv="Kinnex_16S_decat_demux_env"
source /etc/profile.d/conda.sh
conda activate ${myenv} || \
  ( echo "# the conda environment ${myenv} was not found on this machine" ;
    echo "# please read the top part of the script!" \
    && exit 1 )

# check executables present
declare -a arr=( "yq" "skera" "lima" "bam2fastq" "pigz" "scripts/barcode_QC_Kinnex.sh" )
for prog in "${arr[@]}"; do
$( hash ${prog} 2>/dev/null ) || ( echo "# required ${prog} not found in PATH"; exit 1 )
done

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
    echo "config.yaml file not found. Please create the config.yaml file."
    exit 1
fi

# Load variables from config.yaml
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

# conda does not install yq version 4 required for the following command syntax
# eval $(yq e '. as $item ireduce ("";  . + "export " + ($item | to_entries | .[] | .key + "=\"" + .value + "\" "))' config.yaml)

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
touch "$flag_file"
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

cmd="$(which skera) split \
  ${outfolder}/${inputs}/${adapterfolder}/${movie}.hifi_reads.${adapterfolder}.bam \
  barcode_files/MAS-Seq_Adapter_v2/mas12_primers.fasta \
  ${outfolder}/${skera_results}/${movie}.skera.bam \
  --num-threads ${nthr_skera} \
  --log-level ${log_skera} \
  --log-file ${outfolder}/${skera_results}/skera_run-log.txt"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
touch "$flag_file"
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

cmd="$(which lima) \
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
touch "$flag_file"
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

for bam in $(find ${outfolder}/${lima_results} -name "*.bam"); do
# rename sample from samplesheet 'Bio Sample'
pfx=$(basename ${bam%.bam})
bcpair=${pfx#HiFi.}
biosample=$(grep ${bcpair} ${outfolder}/${inputs}/${samplesheet} | \
  dos2unix | cut -d, -f 2 | tr -d "\n")

echo "$(which bam2fastq) \
    ${bam} \
    --output ${outfolder}/${fastq_results}/${biosample} \
    --num-threads ${nthr_bam2fastq}" >> job.list
done

# execute job list in batches of \${nthr_bam2fastq_par}
cmd="parallel -j ${par_bam2fastq} --joblog my_job_log.log \
  < job.list && (rm job.list my_job_log.log)"

echo -e "\n# Executing job list in parallel batches"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
touch "$flag_file"
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

# copy Zymo control PDF anad README.txt
cp -r info ${outfolder}/${final_results}/

cp ${outfolder}/${inputs}/${samplesheet} ${outfolder}/${final_results}/
cp ${outfolder}/${skera_results}/${movie}.skera.summary.csv ${outfolder}/${final_results}/skera.summary.csv
cp ${outfolder}/${lima_results}/HiFi.lima.* ${outfolder}/${final_results}/

# move fastq to save room
mv ${outfolder}/${fastq_results} ${outfolder}/${final_results}/

echo -e "# Creating barcode QC report"
projectnum=$(echo ${samplesheet} | cut -d "_" -f 1 | tr -d "\n")
cmd="scripts/barcode_QC_Kinnex.sh \
  -i ${outfolder}/${final_results}/HiFi.lima.counts \
  -r scripts/barcode_QC_Kinnex.Rmd \
  -m ${mincnt} \
  -f ${qc_format} \
  -p ${projectnum} \
  -s ${outfolder}/${inputs}/${samplesheet}"

echo "# ${cmd}"
eval ${cmd} && mv barcode_QC_Kinnex.${qc_format} ${outfolder}/${final_results}/

# Write the flag file upon successful completion
touch "$flag_file"
}

function createArchive {
local flag_file="Archive_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "# create barcode plots
${flag_file}" ]; then
    echo "createArchive: already done."
    return 0 # Exit the function successfully
fi

echo -e "\n# Creating TGZ archive of ${final_results} and its md5sum"

thr=8
pfx="$(echo ${samplesheet} | cut -d '_' -f 1 | tr -d '\n')_archive"

cd ${outfolder}
{ tar cvf - "${final_results}" \
  | pigz -p ${thr} \
  | tee >(md5sum > ${pfx}.tgz_md5.txt) > ${pfx}.tgz; \
  } 2> ${pfx}_content.log

echo -e "# archive ${pfx}.tgz and md5sum ${pfx}.tgz_md5.txt were created"
# fix file path in md5sum
sed -i "s|-|${pfx}.tgz|g" ${pfx}.tgz_md5.txt

echo -e "\n# Checking md5sum"
md5sum -c ${pfx}.tgz_md5.txt | tee -a ${pfx}.tgz_md5-check.txt

# write flag if checksum is OK
if grep -q "OK" "${pfx}.tgz_md5-check.txt"; then
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
