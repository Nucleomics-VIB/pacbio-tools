#!/usr/bin/env bash

# script: run_pb-16s-nf-local.sh
#
# Stephane Plaisance - VIB-NC 2024-06-03 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements:
# pb-16S-nf pipeline installed locally
# NC edits done on the nextflow pipeline files
# user-provided config.yaml in the current folder
# user-provided ExpXXXX_SMRTLink_Barcodefile.csv (defined in the config.yaml)
# usr-provided folder with demuxed fastq.gz read files (defined in the config.yaml)

# define current folder as workdir
workdir=$PWD

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

# modify ${outfolder} to include full path to local folder
outfolder=${workdir}/${outfolder}
mkdir -p ${outfolder}

# redirect all outputs to a single log file
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
(echo -e "sample_name\tncid\tlabel\tmeta1\tmeta2";
(for fq in ${outfolder}/${inputs}/fastq_results/*.fastq.gz; do

# get full label
name=$(basename "$fq" | cut -d "." -f 1)

# add id
ncid=$(echo "${name}" | cut -d "_" -f 1 | tr -d '\r')

# add user provided label
label=$(echo "${name}" | cut -d '_' --complement -f 1 | tr -d '\r')
meta1=$(echo "${name}" | cut -d "_" -f 2 | tr -d '\r')
meta2=$(echo "${name}" | cut -d "_" -f 3 | tr -d '\r')

echo -e "${name}\t${ncid}\t${label}\t${meta1}\t${meta2}"

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

cmd="nextflow run ${tooldir}/main.nf \
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
  -profile docker"

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

echo -e "\n# Creating data_package folder for delivery"

data_package="${outfolder}/data_package"
mkdir -p ${data_package}

# create symlinks to input folders to reduce data duplication
# adding 'h' to the tar archive copies the original files

# alias reads to delivery folder
ln -s ${outfolder}/fastq_results ${data_package}/fastq_reads || return 1

# alias results
ln -s ${outfolder}/results ${data_package}/results || return 1

# add the nextflow report folder with runtime info summaries
cp -r ${outfolder}/report ${data_package}/nextflow_reports || return 1

# add files containing key info to the nextflow_reports copy
cp ${workdir}/.nextflow.log ${data_package}/nextflow_reports/nextflow.log || return 1
cp ${outfolder}/runlog.txt ${data_package}/nextflow_reports/runlog.txt || return 1
cp ${outfolder}/parameters.txt ${data_package}/nextflow_reports/parameters.txt || return 1
cp ${outfolder}/*_samples.tsv ${data_package}/samples.tsv || return 1
cp ${outfolder}/*_metadata.tsv ${data_package}/metadata.tsv || return 1

# Write the flag file upon successful completion
touch "$flag_file"

}

function create_archive {
local flag_file="${outfolder}/06_create_archive_ok"

# Check if the flag file exists and echo "already done" if it does
if [ -f "# create barcode plots
${flag_file}" ]; then
    echo "create_archive: already done."
    return 0 # Exit the function successfully
fi

echo -e "\n# Creating TGZ archive of data_package and its md5sum"

thr=8
pfx="$(basename ${barcodefile} | cut -d '_' -f 1 | tr -d '\n')_archive"

cd ${outfolder}

cmd="{ tar cvfh - data_package \
  | pigz -p ${thr} \
  | tee >(md5sum > ${pfx}.tgz_md5.txt) > ${pfx}.tgz; \
  } 2> ${pfx}_content.txt"

echo "# ${cmd}"
eval ${cmd} 2>> ${log}

echo -e "# archive ${pfx}.tgz and md5sum ${pfx}.tgz_md5.txt were created in ${outfolder}"

# fix file path in md5sum
sed -i "s|-|${pfx}.tgz|g" ${pfx}.tgz_md5.txt 2>> ${log}

echo -e "\n# Checking md5sum"

md5sum -c ${pfx}.tgz_md5.txt | tee -a ${outfolder}/${pfx}.tgz_md5-check.txt

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

time bundle_results

time create_archive
