#!/bin/bash

# isoseqPolished2metrics.sh: 
# extract metrics from isoseq3 polished bam file
#
# Stéphane Plaisance - VIB-NC 2019_05_21, v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )

# check parameters for your system
version="1.0, 2019_05_21"
usage='# Usage: isoseqPolished2metrics.sh
# script version '${version}'
## input files
# [required: -i <polished.bam>]
# [-h for this help]'

while getopts "i:h" opt; do
	case $opt in
		i) infile=${OPTARG} ;;
		h) echo "${usage}" >&2; exit 0 ;;
		\?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
		*) echo "this command requires arguments, try -h" >&2; exit 1 ;;
	esac
done

if [ -z "${infile}" ]; then
	echo "# provide a isoseq3 polished.bam>";
	exit 1
fi

# check for both inputs
if [ ! -f "${infile}" ]; then
    echo "${infile} file not found!";
    exit 1
fi

echo
echo "# parsing polished transcripts BAM file"

samtools view "${infile}" | \
	awk 'BEGIN{FS="\t"; OFS="\t"; print "transcript.ID","length","ib","im","is","iz","iq","zm","RG"}
		{split($1,tid,"/"); split($12,ib,":"); split($13,im,":");
		split($14,is,":"); split($15,iz,":"); split($16,rq,":");
		split($17,zm,":"); split($18,RG,":");
		print tid[2],length($10),ib[3],im[3],is[3],iz[3],rq[3],zm[3],RG[3] }' \
	> polished_metrics.txt	
