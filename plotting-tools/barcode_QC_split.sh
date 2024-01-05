NOT FINISHED
exit 1

#!/bin/bash
# usage: barcode_QC_split.sh -b <barcode file> -i <runid.lima_counts.txt> -p <project#>
# optional: -f <pdf|html (default pdf)>
#
# plot mosaic from barcode CCS results (runID.lima_counts.txt)
# opt: copy bams to new folder
# opt: convert bam to fastq to new folder
#
# Stephane Plaisance - VIB-Nucleomics Core - November-26-2018 v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB
# 1.0, 2022_08_16
# 1.1, 2023_10_19
# 1.2, 2023_12_20

# requirements
# R with packages listed on top of the .Rmd scrips

version="1.1, 2022_10_02"

# path to the barcode_QC.Rmd file (edit to match yours)
rmd_path="/opt/scripts/barcode_QC_v11.Rmd"

usage='# Usage: barcode_QC_split.sh
# -b <barcodes.csv file>
# -i <runid>.lima_counts.txt file from SMRTlink
# -p <opt: NC project code or title>
# -f <opt: output format pdf or HTML (default pdf)>
# -F <opt: convert BAM to fastq (default OFF>)
# -B <opt: copy BAM new folder (default OFF>)
# -h <this help text>
# script version '${version}

while getopts "b:i:p:f:FBh" opt; do
  case $opt in
    b) opt_barcodes=${OPTARG} ;;
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

######################################
# barcodes required for the splitting
if [ -z "${opt_barcodes}" ]; then
   echo
   echo "# no <barcodes.csv> file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_barcodes}" ]; then
	echo
	echo "${opt_barcodes} file not found!"
	exit 1
fi

# infile
if [ -z "${opt_infile}" ]; then
   echo
   echo "# no <runid>.lima_counts.txt file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_infile}" ]; then
	echo
	echo "${opt_infile} file not found!"
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

# store path to runfolder
runfolder=$(dirname ${opt_infile})

# create fastq versions of the bam files
if [[ $convertbam == "true" ]]; then
mkdir -p fastq_results_${opt_project}

# count original bam input files
bamcnt="$(find ${runfolder}/bc* -type f -name "*.bam" | wc -l)"
echo "# found ${bamcnt} BAM files to convert to FASTQ"

echo "# converting barcode BAM files to FASTQ"
# use parallel for speedup
parallel --plus \
  -j4 \
  "bam2fastq {} -o fastq_results/{= s#^\.\/##; s#.*\/##; s#.bam\$##; s#.*\.##; =}" \
  ::: ${runfolder}/bc*/*.bam

touch "bam2fastq_done.flag"

# check if the count of BAM and the count of FASTQ match
fastqcnt=$(find fastq_results_${opt_project} -type f -name "*.fastq.gz" | wc -l)

echo "# ${fastqcnt} FASTQ files written to fastq_results/"

if [[ ${fastqcnt} -ne ${bamcnt} ]]; then
  echo "# the number of created FASTQ files does not match the number of BAM input files"
  exit 1
fi

fi

# cp bam data to subfolder
if [[ $copybam == "true" ]]; then
mkdir -p bam_results
echo "# copying ${bamcnt} barcode BAM files"

for bcf in $(find ${runfolder} -type d -name "bc*"); do
cp -r ${bcf} bam_results/
done

# check if the count of copied BAM and the count original BAM match
bamcnt2=$(find bam_results -type f -name "*.bam" | wc -l)

echo "# ${bamcnt2} BAM files copied to bam_results/"

if [[ ${bamcnt2} -ne ${bamcnt} ]]; then
  echo "# the number of copied BAM files doe not match the number of BAM input files"
  exit 1
fi

fi

exit 0
