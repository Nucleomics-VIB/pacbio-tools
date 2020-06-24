#!/bin/bash

# racon_polish_asm.sh: error correct a assembly using long-reads and Racon
#
# Requirements:
# run on a unix computer installed with racon and dependencies
# more: https://github.com/lbcb-sci/racon
#
# Stephane Plaisance (VIB-NC) 2020/06/21; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2020/06/21"

usage='# Usage: racon_polish_asm.sh -a <fasta assembly> -b <long-reads>
# [optional: -p <platform map-pb|map-ont (default to "map-pb -H")>]
# [optional: -r <polishing rounds|1>]
# [optional: -t <threads|4>]
# [optional: -h <this help text>]
# script version '${version}

while getopts "a:b:p:r:t:h" opt; do
  case $opt in
   a) draft=${OPTARG} ;;
   b) longreads=${OPTARG} ;;
   p) opt_plf=${OPTARG} ;;
   r) opt_rounds=${OPTARG} ;;
   t) opt_thr=${OPTARG} ;;
   h) echo "${usage}" >&2; exit 0 ;;
   \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
   *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# map long-reads to asm
function fminimap2 () {
minimap2 \
  -x ${type} \
  -t ${thr} \
  ${1} \
  ${2} \
| bgzip -c
}

# error correct with racon
function fracon () {
racon \
  -t ${thr} \
  ${1} \
  ${2} \
  ${3}
}

# defaults
startts=$(date +%s)

# test if minimal arguments were provided
if [ -z "${draft}" ]; then
	echo "# no draft assembly provided!"
	echo "${usage}"
	exit 1
fi

if [ ! -f "${draft}" ]; then
	echo "${draft} file not found!"
	exit 1
fi

if [ -z "${longreads}" ]; then
	echo "# no long-read file provided!"
	echo "${usage}"
	exit 1
fi

if [ ! -f "${longreads}" ]; then
	echo "${longreads} file not found!";
	exit 1
fi

# test platform
if [ -z "${pltf}" ];then
  echo "# no platform provided!"
  echo "${usage}"
  exit 1
fi

input=${draft}
rounds=${opt_rounds:-1}
export thr=${opt_thr:-4}

# type can be map-pb or map-ont
# for PB, add -H use homopolymer-compressed k-mer (preferrable for PacBio)
export type=${opt_plf:-"map-pb -H"}

# perform polishing ${rounds} times

for (( i=1; i<="${rounds}"; i++ )); do
	output=${input%_racon*.fa*}_racon${i}x.fa
	fminimap2 ${input} ${longreads} > pb_mapped_${i}x.paf.gz
	fracon ${longreads} pb_mapped_${i}x.paf.gz ${input} > ${output}
	input=${output}
done

endts=$(date +%s)
dur=$(echo "${endts}-${startts}" | bc)
echo "Done in ${dur} sec"
