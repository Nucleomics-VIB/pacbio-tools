#!/bin/bash

# ccsbamfilter.sh: 
# filter a PB CCS BAM file
# output results as a new bam of a fastq (bgzipped)
# filter by:
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
# bgzip for fastq compression

version="1.0, 2020_11_24"

usage='# Usage: ccsbamfilter.sh -i <bam file>
# script version '${version}'
# [optional: -l <min length |0>]
# [optional: -L <max length |1000000>]
# [optional: -a <min accuracy|0>]
# [optional: -p <min pass# |1>]
# [optional: -f <output fastq instead of bam>]'

while getopts "i:l:L:a:p:fh" opt; do
  case $opt in
    i) bamfile=${OPTARG} ;;
    l) optminl=${OPTARG} ;;
    L) optmaxl=${OPTARG} ;;
    a) optmina=${OPTARG} ;;
    p) optminp=${OPTARG} ;;
    f) optfrmt="fastq" ;;
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
outfmt=${optfrmt:-"bam"}
outpfx=$(basename ${bamfile%.bam})_minl-${minlen}_maxl-${maxlen}_mina-${minacc}_minpass-${minpass}

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )
$( hash awk 2>/dev/null ) || ( echo "# awk not found in PATH"; exit 1 )
$( hash bgzip 2>/dev/null ) || ( echo "# bgzip not found in PATH"; exit 1 )

if [ "${outfmt}" == "bam" ]; then

# make it a bam
samtools view -h ${bamfile} | \
awk -v minl="${minlen}" \
-v maxl="${maxlen}" \
-v mina="${minacc}" \
-v minp="${minpass}" \
'BEGIN{FS="\t"; OFS="\t"}
{if ($1 ~ /^@/) print $0;
else if ($14 ~ /np:i/){
len=length($10); split($14,np,":"); split($15,rq,":");
if (len >= minl && len <= maxl && rq[3] >= mina && np[3] >= minp){
print $0
}
}
}' | samtools view -Sb > "${outpfx}.bam"

else

# make it a fastq.gz
samtools view -h ${bamfile} | \
awk -v minl="${minlen}" \
-v maxl="${maxlen}" \
-v mina="${minacc}" \
-v minp="${minpass}" \
'BEGIN{FS="\t"; OFS="\t"}
{if ($14 ~ /np:i/){
len=length($10); split($14,np,":"); split($15,rq,":");
if (len >= minl && len <= maxl && rq[3] >= mina && np[3] >= minp){
print "@"$1" len:"len" accuracy:"rq[3]" passes:"np[3]"\n"$10"\n+\n"$11
}
}
}' | bgzip -c > "${outpfx}.fq.gz"

fi
