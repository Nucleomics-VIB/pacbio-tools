#!/bin/bash
# script: copy_ccs-demux_results.sh
#
# Stéphane Plaisance - VIB-Nucleomics Core - 2021-01-20 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# provide the "auto ccs-demux" job number from GUI (eg 45)
# copy CCS & demux minimal results to local folder for data transfer

# REM: if CCS and demux have been done separately, also run for CCS job to get ccs.report.csv.zip and add it manually to the main output 

version="2021-01-20, 1.0"

usage='## Usage: copy_ccs-demux_results.sh -j <JOB number from SMRTLink UI> ...
# SP@NC, script version '${version}

# parse parameters
while getopts "j:h" opt; do
    case $opt in
        j) job=$OPTARG ;;
        h) echo "${usage}" >&2; exit 0 ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
        *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
    esac
done

# mandatory
if [ -z "${job}" ]; then
    echo "# no job number was provided!"
    echo "${usage}"
    exit 1
fi

# derive full folder name with leading 0's (as a string)
folder=$(printf "%010s" "${job}")

# define path
ccspath=$(readlink -f "$SMRT_JOBS/${folder}/cromwell-job")

# test if exists and abort
if [ ! -d "${ccspath}" ]; then
        echo "# the path was not found, check that the job ID is correct and restart this script."
        exit 0
fi

# create output folders
outfolder="job-${folder}_results"
mkdir -p ${outfolder}/{reads,bams}

# copy ccs.report.csv
find $ccspath -name "ccs.report.csv.zip" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy barcode_ccs_plots
find $ccspath -name "bq_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find $ccspath -name "nreads_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find $ccspath -name "nreads.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find $ccspath -name "readlength_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy barcode_ccs_summary
find $ccspath -name "barcode_ccs_summary.csv" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy fastx
find $ccspath -name "*.fast?.zip" -exec cp {} "${outfolder}/reads/" \; 2>/dev/null

# copy bam files
find $ccspath -name "demultiplex*.bam" -exec cp {} "${outfolder}/bams/" \; 2>/dev/null

echo "## copy done"
echo
tree -h -L 2 "${outfolder}"
