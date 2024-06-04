#!/usr/bin/env bash

# script: Kinnex_16S_decat_demux.sh
# run skera and lima on a Kinnex 16S RUN
# 
# Stephane Plaisance - VIB-NC 2024-06-03 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements:
# yq
# SMRTLink (crated using v13.1)
# config.yaml (edited and pointing to existing files

# All parameters have been externalised from the code and are listed in config.yaml

# redirect all outputs to a log file
cat /dev/null > runlog.txt
exec &> >(tee -a runlog.txt)

# Check if yq is installed
if ! command -v yq &> /dev/null; then
    echo "yq could not be found. Please install yq to continue."
    exit 1
fi

# Check if config.yaml exists
if [ ! -f "config.yaml" ]; then
    echo "config.yaml file not found. Please create the config.yaml file."
    exit 1
fi

# Load variables from config.yaml
eval $(yq e '. as $item ireduce (""; . + "export " + ($item | to_entries | .[] | .key + "=\"" + .value + "\" "))' config.yaml)

########## FUNCTIONS ###########

function CopyBarcodeFiles {
local flag_file="${reference}/CopyBarcodeFiles_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "CopyBarcodeFiles: already done"
    return 0 # Exit the function successfully
fi

mkdir -p "${reference}"

echo "# Copying Pacbio barcode files locally"

# Find and copy the MAS barcode directory
barcode_dir=$(find "${SMRT_BUNDLES}" -type d -name "barcodes" 2>/dev/null | head -n 1)
if [ -d "${barcode_dir}" ]; then
    cp -r ${barcode_dir}/MAS_adapter_indexes ${reference}/
    cp -r ${barcode_dir}/MAS-Seq_Adapter_v2 ${reference}/
    cp -r ${barcode_dir}/Kinnex16S_384plex_primers ${reference}/
else
    echo "SMRTLink barcode directory not found."
    return 1 # Exit the function with an error status
fi

# Write the flag file upon successful completion
touch "$flag_file"
}

function CopyRunData {
local flag_file="${inputs}/CopyRunData_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "CopyRunData: already done."
    return 0 # Exit the function successfully
fi

mkdir -p "${inputs}"

echo -e "\n# Copying RUN data locally"

# Check if the adapter folder exists
if [ -d "${runfolder}/${adapterfolder}" ]; then
    cp -r "${runfolder}/${adapterfolder}" "${inputs}/"
else
    echo "Adapter folder not found: ${runfolder}/${adapterfolder}"
    return 1 # Exit the function with an error status
fi

# Check if the sample sheet exists
if [ -f "${runfolder}/${samplesheet}" ]; then
    cp "${runfolder}/${samplesheet}" "${inputs}/"
else
    echo "Sample sheet not found: ${runfolder}/${samplesheet}"
    return 1 # Exit the function with an error status
fi

# Write the flag file upon successful completion
touch "$flag_file"
}

function SkeraSplit {
local flag_file="${skera_results}/SkeraSplit_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "SkeraSplit: already done."
    return 0 # Exit the function successfully
fi

mkdir -p ${skera_results}

echo -e "\n# Running Skera de-concatenation"

cmd="${SKERA_PATH} split \
  ${inputs}/${adapterfolder}/${movie}.hifi_reads.${adapterfolder}.bam \
  ${reference}/MAS-Seq_Adapter_v2/mas12_primers.fasta \
  ${skera_results}/${movie}.skera.bam \
  --num-threads ${nthr_skera} \
  --log-level ${log_skera} \
  --log-file ${skera_results}/skera_run-log.txt"
  
echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
touch "$flag_file"
}

function Lima {
local flag_file="${lima_results}/Lima_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "Lima: already done."
    return 0 # Exit the function successfully
fi

mkdir -p ${lima_results}

echo -e "\n# Running Lima demultiplexing"

cmd="${LIMA_PATH} \
  ${skera_results}/${movie}.skera.bam \
  ${reference}/Kinnex16S_384plex_primers/Kinnex16S_384plex_primers.fasta \
  ${lima_results}/HiFi.bam \
  --hifi-preset ASYMMETRIC \
  --split-named \
  --biosample-csv ${inputs}/${samplesheet} \
  --split-subdirs \
  --num-threads ${nthr_lima} \
  --log-level ${log_lima} \
  --log-file ${lima_results}/lima_run-log.txt"
  
echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
touch "$flag_file"
}

function bam2fastq {
local flag_file="${lima_results}/bam2fastq_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "bam2fastq: already done."
    return 0 # Exit the function successfully
fi

mkdir -p ${fastq_results}
cat /dev/null > job.list
  
echo -e "\n# Preparing job list from all lima BAM files"

for bam in $(find ${lima_results} -name "*.bam"); do
# rename sample from samplesheet 'Bio Sample'
pfx=$(basename ${bam%.bam})
bcpair=${pfx#HiFi.}
biosample=$(grep ${bcpair} ${inputs}/${samplesheet} | dos2unix | cut -d, -f 2 | tr -d "\n")

echo "${BAM2FASTQ_PATH} \
    ${bam} \
    --output ${fastq_results}/${biosample} \
    --num-threads ${nthr_bam2fastq}" >> job.list
done

# execute job list in batches of \${nthr_bam2fastq_par}
cmd="parallel -j ${par_bam2fastq} --joblog my_job_log.log < job.list && (rm job.list my_job_log.log)"

echo -e "\n# Executing job list in parallel batches"

echo "# ${cmd}"
eval ${cmd}

# Write the flag file upon successful completion
touch "$flag_file"
}

function BundleResults {
local flag_file="BundleResults_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "BundleResults: already done."
    return 0 # Exit the function successfully
fi

mkdir -p ${final_results}/info

echo -e "\n# Copying files to final_result folder for transfer"

# copy run_QC from RUN folder
cp ${runfolder}/*.pdf ${final_results}/

# copy Zymo control PDF anad README.txt
cp ${ZYMOCTRL} ${final_results}/info/
cp ${README} ${final_results}/

cp ${inputs}/${samplesheet} ${final_results}/
cp ${lima_results}/HiFi.lima.* ${final_results}/

# move fastq to save room
mv ${fastq_results} ${final_results}/

# create barcode plots
projectnum=$(echo ${samplesheet} | cut -d "_" -f 1 | tr -d "\n")
cmd="$PLOT_SH -i ${final_results}/HiFi.lima.counts -m ${mincnt} -f ${qc_format} -p ${projectnum} -s ${inputs}/${samplesheet}"

echo "# ${cmd}"
eval ${cmd} && cp barcode_QC_Kinnex.${qc_format} ${final_results}/

# Write the flag file upon successful completion
touch "$flag_file"
}

function createArchive {
local flag_file="Archive_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "${flag_file}" ]; then
    echo "createArchive: already done."
    return 0 # Exit the function successfully
fi

echo -e "\n# Creating TGZ archive of ${final_results} and its md5sum"

thr=8
pfx="$(echo ${samplesheet} | cut -d '_' -f 1 | tr -d '\n')_archive"

{ tar cvf - "${final_results}" | pigz -p ${thr} | tee >(md5sum > ${pfx}.tgz_md5.txt) > ${pfx}.tgz; } 2> ${pfx}_content.log

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

time CopyBarcodeFiles

time CopyRunData

time SkeraSplit

time Lima

time bam2fastq

time BundleResults

time createArchive
