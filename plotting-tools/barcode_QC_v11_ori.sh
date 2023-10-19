#!/bin/bash
# usage: barcode_QC_v11.sh -i <runid.lima_counts.txt> -p <project#>
# optional: -f <pdf|html (default pdf)>
#
# plot mosaic from barcode CCS results (runID.lima_counts.txt)
#
# Stephane Plaisance - VIB-Nucleomics Core - November-26-2018 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB
# 1.0, 2022_08_16

# requirements
# R with packages listed on top of the .Rmd scrips

version="1.1, 2022_10_02"

# path to the barcode_QC.Rmd file (edit to match yours)
rmd_path="/opt/scripts/barcode_QC_v11.Rmd"

usage='# Usage: barcode_QC_v11.sh
# -i <runid>.lima_counts.txt file from SMRTlink
# -p <opt: NC project code or title>
# -f <opt: output format pdf or HTML (default pdf)>
# -F <opt: convert BAM to fastq (default OFF>)
# -B <opt: copy BAM new folder (default OFF>)
# -h <this help text>
# script version '${version}

while getopts "i:p:f:FBh" opt; do
  case $opt in
    i) opt_infile=${OPTARG} ;;
    p) opt_project=${OPTARG} ;;
    f) opt_format=${OPTARG} ;;
    F) convertbam=true;;
    B) copybam=true;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

#############################
# infile
if [ -z "${opt_infile}" ]; then
   echo
   echo "# no barcode_ccs file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_infile}" ]; then
	echo
	echo "${ipt_infile} file not found!"
	exit 1
fi

# project
if [ -z "${opt_project}" ]; then
   echo
   echo "# no project code or title provided!"
   echo "${usage}"
   exit 1
fi

# default to pdf
format=${opt_format:-"pdf"}

if [[ ${format} == "pdf" ]]; then
outformat="pdf_document"
else
outformat="html_document"
fi

cmd="R --slave -e 'rmarkdown::render(
  input=\"${rmd_path}\",
  output_format=\"${outformat}\",
  output_dir=\"$PWD\",
  params=list(expRef=\"${opt_project}\",inputFile=\"$PWD/${opt_infile}\")
  )'"

echo "# ${cmd}"
eval ${cmd}

# create fastq versions of the bam files
if [[ $convertbam == "true" ]]; then
mkdir -p fastq_results

# good-old way
#for b in $(find . -name "*.bam" -not -name "*unbarcoded*");
#do pfx=$(basename ${b} ".bam")
#echo "# converting ${b} to fastq"
#bam2fastq ${b} -o fastq_results/${pfx}
#done

echo "# converting barcode data to fastq"
# use parallel for speedup
parallel --plus \
  -j4 \
  "bam2fastq {} -o fastq_results/{= s#^\.\/##; s#.*\/##; s#.bam\$##; s#.*\.##; =}" \
  ::: $(dirname ${opt_infile})/bc*/*.bam
fi

# cp bam data to subfolder
if [[ $copybam == "true" ]]; then
mkdir -p bam_results
echo "# copying barcode BAM data"
for bcf in $(find $(dirname ${opt_infile}) -type d -name "bc*"); do
cp -r ${bcf} bam_results/
done
fi

exit 0
