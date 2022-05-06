#!/bin/bash

# script: copy_ccs-demux_results_local.sh
#
# Stéphane Plaisance - VIB-Nucleomics Core - 2022-05-03 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# provide the local path to a restored job folder
# copy CCS & demux minimal results to local folder for data transfer

version="2022-05-03, 1.0"

usage='## Usage: copy_ccs-demux_results_local.sh -f <local job folder path> 
# -f path to local copy of demux folder
# -r path to local copy of run folder (default to .)
# -o name for output folder (default to "demux_results")
# SP@NC, script version '${version}

# parse parameters
while getopts "f:r:o:h" opt; do
    case $opt in
        f) folder=$OPTARG ;;
        r) opt_run=$OPTARG ;;
        o) opt_out=$OPTARG ;;
        h) echo "${usage}" >&2; exit 0 ;;
        \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
        *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
    esac
done

# mandatory
if [ -z "${folder}" ]; then
    echo "# no job folder path was provided!"
    echo "${usage}"
    exit 1
fi

# create output folders
outfolder="${opt_out:-"demux_results"}"
mkdir -p ${outfolder}/{reads,bams}

# locate local copy of run_folder to fetch ccs_report
runfolder="${opt_run:-\.}"

# copy ccs.report.csv from the run folder (HIFI run with CCS)
find ${runfolder} -name "*.ccs_reports.txt" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy barcode_ccs_plots
find ${folder} -name "bq_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find ${folder} -name "nreads_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find ${folder} -name "nreads.png" -exec cp {} "${outfolder}/" \; 2>/dev/null
find ${folder} -name "readlength_histogram.png" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy barcode_ccs_summary
find ${folder} -name "barcode_ccs_summary.csv" -exec cp {} "${outfolder}/" \; 2>/dev/null

# copy fastq files
find ${folder} -name "*.fastq.gz" -exec cp {} "${outfolder}/reads/" \; 2>/dev/null

# copy bam files
find ${folder} -name "demultiplex*.bam" -exec cp {} "${outfolder}/bams/" \; 2>/dev/null

echo "## copy done"
echo
tree -h -L 2 "${outfolder}"

# echo "# creating tgz archive and md5sum"
echo
tar --use-compress-program="pigz -p 8 " \
  -h \
  -cvf \
  "${outfolder}.tgz" \
  "${outfolder}" && \
    md5sum "${outfolder}.tgz" > "${outfolder}.tgz_md5.txt" && \
    md5sum -c "${outfolder}.tgz_md5.txt" > "${outfolder}.tgz_md5_check.txt"
