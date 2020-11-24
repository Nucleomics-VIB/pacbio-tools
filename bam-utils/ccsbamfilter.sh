#!/bin/bash

# ccsbamfilter.sh: 
# filter a PB CCS BAM file
# output results as a new bam# filter by:
# - min and max insert length
# - min Accuracy
# - min ccs pass number
#
# Stéphane Plaisance - VIB-NC-BITS Nov-19-2020 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam
# GNU awk for parsing sam data

version="1.0, 2020_11_24"

usage='# Usage: ccsbamfilter.sh -i <bam file>
# script version '${version}'
# [optional: -l <min length |0>]
# [optional: -L <max length |1000000>]
# [optional: -a <min accuracy|0>]
# [optional: -p <min pass# |1>]'

while getopts "i:l:L:a:p:h" opt; do
  case $opt in
    i) bamfile=${OPTARG} ;;
    l) optminl=${OPTARG} ;;
    L) optmaxl=${OPTARG} ;;
    a) optmina=${OPTARG} ;;
    p) optminp=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# test if minimal arguments were provided
if [ -z "${bamfile}" ]
then
   echo "# no bam provided!"
   echo "${usage}"
   exit 1
fi

# default values
minlen=${optminl:-0}
maxlen=${optmaxl:-1000000}
minacc=${optmina:-0}
minpass=${optminp:-1}

outfile=$(basename ${bamfile%.bam})_minl-${minlen}_maxl-${maxlen}_mina-${minacc}_minpass-${minpass}.bam

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )
$( hash awk 2>/dev/null ) || ( echo "# awk not found in PATH"; exit 1 )

samtools view -h ${bamfile} | \
awk -v minl="${minlen}" -v maxl="${maxlen}" -v mina="${minacc}" -v minp="${minpass}" \
'BEGIN{FS="\t"; OFS="\t"}
{if ($1 ~ /^@/) print $0;
else if ($14 ~ /np:i/){
len=length($10); split($14,np,":"); split($15,rq,":");
if (len >= minl && len <= maxl && rq[3] >= mina && np[3] >= minp){
print $0
}
}
}' | samtools view -Sb > ${outfile}
