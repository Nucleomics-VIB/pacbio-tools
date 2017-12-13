#!/bin/bash

# arrow_polish_asm.sh: error correct a assembly using PacBio reads and Arrow
#
# Requirements:
# run on a unix computer installed with SMRTLink
# SMRT tools installed (blasr, arrow, ...)
# draft assembly fasta present
# Sequel reads in BAM format (should be generated from RSII hd5 data first)
# merging from several smrt-cells: samtools cat ../reads/m*.subreads.bam > merged.subreads.bam
# readings in https://github.com/PacificBiosciences/PacBioFileFormats/wiki/BAM-recipes
#
# Stephane Plaisance (VIB-NC+BITS) 2017/12/13; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2017_12_13"

usage='# Usage: arrow_polish_asm.sh -a <fasta assembly> -b <sequel reads (bam)> 
# [optional: -p <smrt_bin path> (suggested: '$SMRT_APPS')
# [optional: -o <result folder>]
# [optional: -t <available threads|1>]
# [optional: -h <this help text>]
# script version '${version}

while getopts "a:b:p:o:t:h" opt; do
  case $opt in
    a) draftassembly=${OPTARG} ;;
    b) sequelreads=${OPTARG} ;;
    p) smrtbinpath=${OPTARG} ;;
    o) outpath=${OPTARG} ;;
    t) threads=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# defaults
startts=$(date +%s)

# test if minimal arguments were provided
if [ -z "${draftassembly}" ]
then
   echo "# no draft assembly provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${draftassembly}" ]; then
	echo "${draftassembly} file not found!"
	exit 1
fi

if [ -z "${sequelreads}" ]
then
	echo "# no BAM file (sequel reads) provided!"
	echo "${usage}"
	exit 1
fi

if [ ! -f "${sequelreads}" ]; then
    echo "${sequelreads} file not found!";
    exit 1
fi

# SMRT bin PATH
binpath=${smrtbinpath:-${SMRT_APPS}}

# check if requirements are present
$( hash ${binpath}/pbalign 2>/dev/null ) || ( echo "# pbalign not found in ${binpath}"; exit 1 )
$( hash ${binpath}/arrow 2>/dev/null ) || ( echo "# arrow not found in ${binpath}"; exit 1 )

# files and folders
draftname=$(basename ${draftassembly})
destfolder=${outpath:-"arrow-polished-${draftname%.*}"}
mkdir -p ${destfolder} || ( echo "# could not create destination folder"; exit 1 )

# from here down, redirect all outputs to log file
exec > >(tee -a ${destfolder}/arrow-polished-${draftname%.*}-log.txt) 2>&1

# 1) map reads to the draft assembly with pbalign:blasr
cmd="${binpath}/pbalign --algorithm blasr --nproc ${threads} \
	${sequelreads} ${draftassembly} ${destfolder}/blasr.bam"

echo "# mapping reads with: ${cmd}"
eval ${cmd}

if [ $? -ne 0 ]; then
	echo "# something went wrong with the mapping of bam data to the assembly"
	exit 1
fi

# 2) Use arrow for polishing the assembly using following command:
cmd="${binpath}/arrow ${destfolder}/blasr.bam \
	--referenceFilename ${draftassembly} \
	-o ${destfolder}/arrow-polished-${draftname%.*}.fasta \
	-o ${destfolder}/arrow-polished-${draftname%.*}.gff \
	-o ${destfolder}/arrow-polished-${draftname%.*}.fastq \
	-j ${threads}"

# show and execute	
echo "# correcting assembly with: ${cmd}"
eval ${cmd}
 
endts=$(date +%s)
dur=$(echo "${endts}-${startts}" | bc)
echo "Done in ${dur} sec"
