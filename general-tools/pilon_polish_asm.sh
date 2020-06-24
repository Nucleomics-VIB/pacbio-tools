#!/bin/bash

# pilon_polish_asm.sh: error correct a assembly using Illumina PE-reads and Pilon
#
# Requirements:
# run on a unix computer installed
# BWA, Pilon, samtools
# draft assembly fasta present
# Illumina PE reads
#
# Stephane Plaisance (VIB-NC) 2017/12/13; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2020_06_12"

usage='# Usage: pilon_polish_asm.sh -i <fasta assembly> -1 <forward PE reads> -2 <reverse PE reads>
# [optional: -r <polishing rounds|1>
# [optional: -t <threads|1>]
# [optional: -T <threads2|1>]
# [optional: -m <javamem|4G>]
# [optional: -h <this help text>]
# script version '${version}

while getopts "i:1:2:r:t:T:m:h" opt; do
  case $opt in
    i) draft=${OPTARG} ;;
    1) read1=${OPTARG} ;;
    2) read2=${OPTARG} ;;
    r) opt_rounds=${OPTARG} ;;
    t) opt_thr=${OPTARG} ;;
    T) opt_thr2=${OPTARG} ;;
    m) opt_mem==${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

startts=$(date +%s)

##########################
# wrapper functions
##########################

# map paired-reads to asm
function fbwamap () {
bwa index ${1} -p ${1%.fa*}
bwa mem \
  -t ${thr} \
  ${1%.fa*} \
  ${2} \
  ${3} \
| samtools view -F 4 - -Sb \
| samtools sort -@${thr2} -
}

# error correct with racon
function fpilon () {
java -Xmx${mem} -jar $PILON/pilon.jar \
--genome ${1} \
--fix all \
--changes \
--frags ${2} \
--threads ${thr} \
--output pilon${3}x \
| tee pilon${3}x.log
}

#############################################
# test if minimal arguments were provided
#############################################

if [[ -z "${draft}" ]]
then
  echo "# no draft assembly provided!"
  echo "${usage}"
  exit 1
fi

if [[ ! -f "${draft}" ]]; then
	echo "${draft} file not found!"
	exit 1
fi

if [[ -z "${read1}" ]] || [[ -z "${read2}" ]]; then
	echo "# requires paired reads from two files!"
	echo "${usage}"
	exit 1
fi

if [[ ! -f "${read1}" ]] ; then
    echo "reads file ${read1} not found!";
    exit 1
fi

if [[ ! -f "${read2}" ]]; then
    echo "reads file ${read2} not found!";
    exit 1
fi

# check executables present
declare -a arr=( "bwa" "samtools" "pilon.jar" "egrep" )
for prog in "${arr[@]}"; do
$( hash ${prog} 2>/dev/null ) || \
    ( echo "# required ${prog} not found in PATH"; exit 1 )
done

##############################################
# setup defaults
##############################################

currpath=$(pwd)

# files and folders
draftname=$(basename ${draft})
destfolder="${currpath}/pilon-polished-${draftname%.fa*}"
mkdir -p ${destfolder} || ( echo "# could not create destination folder"; exit 1 )

# get raw data in place
cp ${draft} ${destfolder}/draft.fa
cd ${destfolder}
ln -f -s ../${read1} .
ln -f -s ../${read2} .

rounds=${opt_rounds:-1}

export R1=$(basename ${read1})
export R2=$(basename ${read2})

export thr=${opt_thr:-1}
export thr2=${opt_thr2:-1}
export mem=${opt_mem:-"4G"}

# from here down, redirect all outputs to log file
exec > >(tee -a ${destfolder}/pilon-polished-${draftname%.*}-log.txt) 2>&1

##############################################
# run wrapper for rounds of pilon polishing
##############################################

input="draft.fa"

for (( i=1; i<="${rounds}"; i++ )); do
	fbwamap ${input} ${R1} ${R2} > mapped_${i}x.bam \
	  && samtools index mapped_${i}x.bam
	fpilon ${input} mapped_${i}x.bam ${i} \
	  || exit 1
	input=pilon${i}x.fasta
	# test if pilon found changes
	[[ -s pilon${i}x.changes ]] \
	  || (echo "# no changes after round ${i}, exiting!" && break)
done

##############################################
# end
##############################################

endts=$(date +%s)
dur=$(echo "${endts}-${startts}" | bc)
echo "Done in ${dur} sec"

# collect results of 3 rounds
egrep "Confirmed|Corrected" pilon*.log > pilon_summary.txt
