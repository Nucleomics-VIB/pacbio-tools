#!/bin/bash
# script name: pb_STARlong.sh
# run STARlong with some predefined optional parameters
# ref: https://github.com/PacificBiosciences/cDNA_primer/wiki/Bioinfx-study:-Optimizing-STAR-aligner-for-Iso-Seq-data

## Requirements:
# STAR installed (version > 2.4)
#
# Stephane Plaisance (VIB-NC+BITS) 2017/03/03; v1.0
#
# visit our Git: https://github.com/BITS-VIB

# from the wiki page
PARAMS="--runMode alignReads \
--outSAMattributes NH HI NM MD \
--readNameSeparator space \
--outFilterMultimapScoreRange 1 \
--outFilterMismatchNmax 2000 \
--scoreGapNoncan -20 \
--scoreGapGCAG -4 \
--scoreGapATAC -8 \
--scoreDelOpen -1 \
--scoreDelBase -1 \
--scoreInsOpen -1 \
--scoreInsBase -1 \
--alignEndsType Local \
--seedSearchStartLmax 50 \
--seedPerReadNmax 100000 \
--seedPerWindowNmax 1000 \
--alignTranscriptsPerReadNmax 100000 \
--alignTranscriptsPerWindowNmax 10000 "

version="1.0, 2017_03_03"

usage='# Usage: pb_STARlong.sh 
	-q <query sequences (reads)> 
	-d <STAR_database-folder>
# optional -t <threads> (default 8)>
# script version '${version}'
# [-h for this help]'

while getopts "q:d:t:h" opt; do
  case $opt in
    q) query=${OPTARG} ;;
    d) database=${OPTARG} ;;
    t) threads=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# is STARlong in PATH?
if [ ! $(type -P STARlong) ]
then
	echo "# STARlong not found in PATH!";
	#exit 1	
fi

if [ -z "${query+x}" ] || [ -z "${database+x}" ]
then
   echo "# please provide mandatory arguments -q and -d!"
   echo "${usage}"
   exit 1
fi

nthr=${threads:-8}

cmd="STARlong \
	$PARAMS \
	--runThreadN ${nthr} \
	--readFilesIn=${query} \
	--genomeDir=${database} \
	2>&1 > pb_STARlong-run_log.txt"

echo "##${cmd}"

