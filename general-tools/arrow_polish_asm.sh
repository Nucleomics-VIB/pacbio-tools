#!/bin/bash

# arrow_polish_asm.sh: error correct a assembly using PacBio reads and Arrow
#
# Requirements:
# run on a unix computer installed with SMRTLink and Picard
# SMRT tools installed (blasr, arrow, ...)
# Picard tools for sorting and indexing the mappings
# draft assembly fasta present
# Sequel reads in BAM format (should be generated from RSII hd5 data first)
# merging from several smrt-cells: samtools cat ../reads/m*.subreads.bam > merged.subreads.bam
# alt: bamtools for bam merging when necessary or use a fofiles as input for blasr
# readings in https://github.com/PacificBiosciences/PacBioFileFormats/wiki/BAM-recipes
# more: https://github.com/PacificBiosciences/GenomicConsensus/blob/master/doc/FAQ.rst
#
# Stephane Plaisance (VIB-NC+BITS) 2017/12/13; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2017_12_13"

usage='# Usage: arrow_polish_asm.sh -a <fasta assembly> -b <sequel_reads (bam)>
# [optional: -c <min coverage for analysis|5>]
# [optional: -C <max coverage for analysis|100>]
# [optional: -p <smrt_bin path> (found at: '$SMRT_APPS')
# [optional: -P <picard.jar path> (found at: '$PICARD')
# [optional: -o <result folder>]
# [optional: -t <threads|4>]
# [optional: -h <this help text>]
# script version '${version}

while getopts "a:b:c:C:p:P:o:t:h" opt; do
  case $opt in
    a) draftassembly=${OPTARG} ;;
    b) sequelreads=${OPTARG} ;;
    c) mincoverage=${OPTARG} ;;
    C) maxcoverage=${OPTARG} ;;
    p) smrtbinpath=${OPTARG} ;;
    P) picardpath=${OPTARG} ;;
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
picard=${picardpath:-${PICARD}}
currpath=$(pwd)

# check if requirements are present
hash "${binpath}/blasr" 2>/dev/null || ( echo "# blasr not found in ${binpath}"; exit 1 )
hash "${binpath}/arrow" 2>/dev/null || ( echo "# arrow not found in ${binpath}"; exit 1 )
hash java 2>/dev/null || ( echo "# java not found"; exit 1 )
[ -f "${picard}/picard.jar" ] || ( echo "# picard.jar not found in ${picard}"; exit 1 )

# files and folders
draftname=$(basename ${draftassembly})
destfolder=${outpath:-"arrow-polished-${draftname%.*}"}
mkdir -p ${destfolder} || ( echo "# could not create destination folder"; exit 1 )

# from here down, redirect all outputs to log file
exec > >(tee -a ${destfolder}/arrow-polished-${draftname%.*}-log.txt) 2>&1

# 1) map reads to the draft assembly with pbalign:blasr

thr=${threads:-4}
cmd="${binpath}/blasr ${sequelreads} ${draftassembly} \
	--bam \
	--nproc ${thr} \
	--out ${destfolder}/blasr.bam"

echo "# mapping reads with: ${cmd}"
eval ${cmd}

if [ $? -ne 0 ]; then
	echo "# something went wrong with the mapping of bam data to the assembly"
	exit 1
fi

# 2) sort mappings by coordinate and index (work on local path to avoid tmp overflow)

cmd="java -jar $PICARD/picard.jar SortSam \
	I=${destfolder}/blasr.bam \
	O=${destfolder}/sorted_blasr.bam \
	SO=coordinate \
	MAX_RECORDS_IN_RAM=100000 \
	TMP_DIR=${currpath} \
	CREATE_INDEX=true \
	VALIDATION_STRINGENCY=LENIENT"

echo
echo "# sorting mappings with: ${cmd}"
eval ${cmd}

if [ $? -ne 0 ]; then
	echo "# something went wrong with the bam sorting and indexing"
	exit 1
else
	# delete original mappings to recover disk space
	rm ${destfolder}/blasr.bam
	
	# also create pbindex (.pbi)
	cmd="pbindex ${destfolder}/sorted_blasr.bam"
	
	echo
	echo "# creating pbi index with : ${cmd}"
	eval ${cmd}

	if [ $? -ne 0 ]; then
		echo "# something went wrong with bam pbindex"
		exit 1
	fi
fi

# 3) Use arrow for polishing the assembly using following command:

# coverage limits for arrow analysis
mincvg=${mincoverage:-5}
maxcvg=${maxcoverage:-100}

# number of concurrent workers
numwrk=$(echo "${thr}"/4 | bc)
# avoid 0 when less than 4 threads
if [[ ${numwrk} == 0 ]]; then
	numwrk=1
fi

cmd="${binpath}/arrow ${destfolder}/sorted_blasr.bam \
	--referenceFilename ${draftassembly} \
	--minCoverage ${mincvg} \
	--coverage ${maxcvg} \
	-j ${numwrk} \
	-o ${destfolder}/arrow-polished-${draftname%.*}.fasta \
	-o ${destfolder}/arrow-polished-${draftname%.*}.gff \
	-o ${destfolder}/arrow-polished-${draftname%.*}.fastq"

# show and execute
echo
echo "# correcting assembly with: ${cmd}"
eval ${cmd}
 
endts=$(date +%s)
dur=$(echo "${endts}-${startts}" | bc)
echo "Done in ${dur} sec"
