#!/bin/bash

# ccsbamfilter.sh: 
# filter a PB CCS BAM file
# output results as a new bam or a fastq (bgzipped)
# filter ccs reads by:
# - min and max insert length
# - min Accuracy
# - min and max ccs pass number
#
# Stéphane Plaisance - VIB-NC-BITS Nov-19-2020 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam
# GNU awk for parsing sam data
# bgzip for fastq compression

version="1.1, 2020_11_25"

usage='# Usage: ccsbamfilter.sh -i <bam file>
# script version '${version}'
# [optional: -l <min length |0>]
# [optional: -L <max length |1000000>]
# [optional: -a <min accuracy|0>]
# [optional: -p <min pass# |1>]
# [optional: -P <max pass# |10000>]
# [optional: -f <output fastq instead of bam>]'

while getopts "i:l:L:a:p:P:fh" opt; do
  case $opt in
    i) bamfile=${OPTARG} ;;
    l) optminl=${OPTARG} ;;
    L) optmaxl=${OPTARG} ;;
    a) optmina=${OPTARG} ;;
    p) optminp=${OPTARG} ;;
    P) optmaxp=${OPTARG} ;;
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
maxpass=${optmaxp:-10000}
outfmt=${optfrmt:-"bam"}
outpfx=$(basename ${bamfile%.bam})_minl-${minlen}_maxl-${maxlen}_mina-${minacc}_minpass-${minpass}_maxpass-${maxpass}

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
-v maxp="${maxpass}" \
'BEGIN{FS="\t"; OFS="\t"; tot=0; filt=0}
{if ($1 ~ /^@/) print $0;
else if ($14 ~ /np:i/){
tot=tot+1;
len=length($10); split($14,np,":"); split($15,rq,":");
if (len >= minl && len <= maxl && rq[3] >= mina && np[3] >= minp && np[3] <= maxp){
print $0;
filt=filt+1
}
}
}
END{print "total reads:"tot"\nfiltered reads:"filt >> "/dev/stderr"}' \
| samtools view -Sb > "${outpfx}.bam"

else

# make it a fastq.gz
samtools view ${bamfile} | \
awk -v minl="${minlen}" \
-v maxl="${maxlen}" \
-v mina="${minacc}" \
-v minp="${minpass}" \
-v maxp="${maxpass}" \
'BEGIN{FS="\t"; OFS="\t"; tot=0; filt=0}
{if ($14 ~ /np:i/){
tot=tot+1;
len=length($10); split($14,np,":"); split($15,rq,":");
if (len >= minl && len <= maxl && rq[3] >= mina && np[3] >= minp && np[3] <= maxp){
print "@"$1" len:"len" accuracy:"rq[3]" passes:"np[3]"\n"$10"\n+\n"$11
filt=filt+1
}
}
}
END{print "total reads:"tot"\nfiltered reads:"filt >> "/dev/stderr"}' \
| bgzip -c > "${outpfx}.fq.gz"

fi
