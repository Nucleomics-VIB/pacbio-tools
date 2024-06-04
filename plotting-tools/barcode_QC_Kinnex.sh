#!/bin/bash
# usage: barcode_QC_Kinnex.sh 
# -i <pfx.lima.counts.txt> 
# -p <project#>
# -s <samplesheet>
# optional: -m <min read count per sample>
# optional: -f <pdf|html (default pdf)>
#
# plot mosaic from 16S HiFi amplicon results (pfx.lima.counts)
#
# Stephane Plaisance - VIB-Nucleomics Core - November-26-2018 v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB
# 1.0, 2024_05_30

# requirements
# R with packages listed on top of the .Rmd scrips

version="1.0, 2024_05_30"

# path to the barcode_QC.Rmd file (edit to match yours)
rmd_path="/opt/scripts/barcode_QC_Kinnex.Rmd"

usage='# Usage: barcode_QC_Kinnex.sh
# -i <runid>.lima_counts file from SMRTlink
# -m <min read count (default 12000>
# -p <NC project code or title>
# -s <samplesheet (ExpXXXX_SMRTLink_Barcodefile.csv)>
# -f <output format pdf or HTML (default pdf)>
# -h <this help text>
# script version '${version}

while getopts "i:m:p:s:f:h" opt; do
  case $opt in
    i) opt_infile=${OPTARG} ;;
    m) opt_mincnt=${OPTARG} ;;
    p) opt_project=${OPTARG} ;;
    s) opt_samplesheet=${OPTARG} ;;
    f) opt_format=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

#############################
# infile
if [ -z "${opt_infile}" ]; then
   echo
   echo "# no <pfx>.lima.counts file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_infile}" ]; then
	echo
	echo "${opt_infile} file not found!"
	exit 1
fi

# samplesheet
if [ -z "${opt_samplesheet}" ]; then
   echo
   echo "# no samplesheet file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_samplesheet}" ]; then
	echo
	echo "${opt_samplesheet} file not found!"
	exit 1
fi

# project
if [ -z "${opt_project}" ]; then
   echo
   echo "# no project code or title provided!"
   echo "${usage}"
   exit 1
fi

# default mincnt to 12000
mincnt=${opt_mincnt:-12000}

# default to pdf
format=${opt_format:-"html"}

if [[ ${format} == "pdf" ]]; then
outformat="pdf_document"
else
outformat="html_document"
fi

cmd="R --slave -e 'rmarkdown::render(
  input=\"${rmd_path}\",
  output_format=\"${outformat}\",
  output_dir=\"$PWD\",
  params=list(expRef=\"${opt_project}\",inputFile=\"$PWD/${opt_infile}\",mincnt=\"${mincnt}\",samplesheet=\"$PWD/${opt_samplesheet}\")
  )'"

echo "# ${cmd}"
eval ${cmd}

exit 0
