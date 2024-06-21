#!/bin/bash
# usage: barcode_QC_Kinnex.sh
# -r <path to the Rmd plotting script>
# -i <runid>.lima_counts file from SMRTlink
# -m <min read count (default 12000>
# -p <NC project code or title>
# -s <samplesheet (ExpXXXX_SMRTLink_Barcodefile.csv)>
# -f <output format pdf or HTML (default pdf)>
# -h <this help text>
#
# plot mosaic from 16S HiFi amplicon results (pfx.lima.counts)
#
# Stephane Plaisance - VIB-Nucleomics Core - November-26-2018 v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB
# 1.0, 2024_05_30
# 1.1, 2024_06_11 ; fixed for running inside conda anv

# requirements
# R with packages listed on top of the .Rmd scrips

version="1.1, 2024_06_11"

usage='# Usage: barcode_QC_Kinnex.sh
# -r <path to the Rmd plotting script>
# -i <runid>.lima_counts file from SMRTlink
# -m <min read count (default 12000>
# -p <NC project code or title>
# -s <samplesheet (ExpXXXX_SMRTLink_Barcodefile.csv)>
# -f <output format pdf or HTML (default pdf)>
# -h <this help text>
# script version '${version}

while getopts "r:i:m:p:s:f:h" opt; do
  case $opt in
    r) opt_rmdfile=${OPTARG} ;;
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
# rmdfile
if [ -z "${opt_rmdfile}" ]; then
   echo
   echo "# no barcode_QC_Kinnex.Rmd script provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_rmdfile}" ]; then
        echo
        echo "${opt_rmdfile} file not found!"
        exit 1
fi

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

cmd="Rscript --vanilla -e 'rmarkdown::render(
  input=\"${opt_rmdfile}\",
  output_format=\"${outformat}\",
  output_dir=\"$PWD\",
  params=list(expRef=\"${opt_project}\",inputFile=\"${opt_infile}\",mincnt=\"${mincnt}\",samplesheet=\"${opt_samplesheet}\")
  )'"

echo "# ${cmd}"
eval ${cmd}

exit 0
