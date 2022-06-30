#!/bin/bash
# usage: barcode_QC.sh -i <barcode_ccs_summary.csv> -p <project#> 
# optional: -f <pdf|html (default pdf)>
# 
# plot barcode CCS results from find optical read duplicates and return counts
# opt: remove duplicates and create output read files
#
# Stephane Plaisance - VIB-Nucleomics Core - November-26-2018 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements
# R with packages listed on top of the .Rmd scrips

version="1.0, 2022_06_24"

# path to the barcode_QC.Rmd file (edit to match yours)
rmd_path="/opt/scripts/barcode_QC.Rmd"

usage='# Usage: barcode_QC.sh 
# -i <barcode_ccs_summary.csv file from SMRTlink>
# -p <opt: NC project code or title>
# -f <opt: output format pdf or HTML (default pdf)>
# -h <this help text>
# script version '${version}

while getopts "i:p:f:h" opt; do
  case $opt in
    i) opt_infile=${OPTARG} ;;
    p) opt_project=${OPTARG} ;;
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
   echo "# no barcode_ccs file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_infile}" ]; then
	echo
	echo "${ipt_infile} file not found!"
	exit 1
fi

filepath=$PWD{pwd}

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

exit 0
