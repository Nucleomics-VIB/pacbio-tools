#!/bin/bash
# script name: pacbio2miniasm.sh
# align reads all to all and generate de-novo assembly with miniasm
# tuned for pacbio reads
#
## Requirements:
# Sequel reads in fasta and fastq formats
# minimap2 and miniasm installed from github
# git clone https://github.com/lh3/minimap2 && (cd miniasm && make)
# git clone https://github.com/lh3/miniasm && (cd miniasm && make)
#
# Stephane Plaisance, VIB-NC 2017/09/21; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="1.0, 2017_09_21"

# check if executables are present
declare -a arr=("samtools" "minimap2" "miniasm" "samtools" "gzip")
for prog in "${arr[@]}"; do
$( hash ${prog} 2>/dev/null ) || ( echo "# required ${prog} not found in PATH"; exit 1 )
done

usage='# Usage: pacbio2miniasm.sh
# -r <reads in fasta format>
# -x <alignment preset for long reads (ava-pb,ava-ont|ava-pb)>
# -o <prefix for output data (default to miniasm_<read file prefix>)>
# -t <max number of threads for aligning (default to 4)>
# script version '${version}'
# [-h for this help]'

while getopts "r:x:o:t:h" opt; do
  case $opt in
    r | --fasta-reads) reads=${OPTARG} ;;
    x | --preset) opt_x=${OPTARG} ;;
    o | --out_prefix) outpfx=${OPTARG} ;;
    t | --max_treads) opt_t=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# test if minimal arguments were provided
if [ -z "${reads}" ]
then
   echo "# no fasta read input provided!"
   echo "${usage}"
   exit 1
fi

# check if exists or die
[ -f ${reads} ] || ( echo "## ERROR! ${reads} file not found" ; exit 1 )

# other defaults
preset=${opt_x:-"ava-pb"}
outpref=${outpfx:-"miniasm_$(basename ${reads%.f*})"}
maxthr=${opt_t:-4}

# create new folder
basedir=$(pwd)
outdir="${basedir}/${outpref}"
mkdir -p ${outdir}

# create log
log=${outdir}/runlog.txt
exec &> >(tee -i ${log})
exec 2>&1

# align all to all
cmd="minimap2 -t ${maxthr} -x ${preset} ${reads} ${reads} \
	| gzip -1 > ${outdir}/overlaps.paf.gz"

echo "# ${cmd}"
echo
eval ${cmd}

# continue on success
if [ $? -eq 0 ]; then

# assemble from alignments
cmd="miniasm -f ${reads} ${outdir}/overlaps.paf.gz \	
	> ${outdir}/${outpref}.gfa"

echo
echo "# ${cmd}"
echo
eval ${cmd}
else
echo "# all to all alignment failed, please check"
exit 1

fi

# continue on success
if [ $? -eq 0 ]; then

# convert to fasta and cut lines at 80 character using fold
awk '/^S/{print ">"$2"\n"$3}' ${outdir}/${outpref}.gfa \
	| fold > ${outdir}/${outpref}.fasta

echo
echo "# all done."
else
echo "# miniasm assembly step failed, please check"
exit 1

fi

exit 0

# Usage: minimap2 [options] <target.fa>|<target.idx> [query.fa] [...]
# Options:
#   Indexing:
#     -H           use homopolymer-compressed k-mer
#     -k INT       k-mer size (no larger than 28) [15]
#     -w INT       minizer window size [{-k}*2/3]
#     -I NUM       split index for every ~NUM input bases [4G]
#     -d FILE      dump index to FILE []
#   Mapping:
#     -f FLOAT     filter out top FLOAT fraction of repetitive minimizers [0.0002]
#     -g INT       stop chain enlongation if there are no minimizers in INT-bp [5000]
#     -r INT       bandwidth used in chaining and DP-based alignment [500]
#     -n INT       minimal number of minimizers on a chain [3]
#     -m INT       minimal chaining score (matching bases minus log gap penalty) [40]
#     -X           skip self and dual mappings (for the all-vs-all mode)
#     -p FLOAT     min secondary-to-primary score ratio [0.8]
#     -N INT       retain at most INT secondary alignments [5]
#     -G NUM       max intron length (only effective following -x splice) [200k]
#   Alignment:
#     -A INT       matching score [2]
#     -B INT       mismatch penalty [4]
#     -O INT[,INT] gap open penalty [4,24]
#     -E INT[,INT] gap extension penalty; a k-long gap costs min{O1+k*E1,O2+k*E2} [2,1]
#     -z INT       Z-drop score [400]
#     -s INT       minimal peak DP alignment score [80]
#     -u CHAR      how to find GT-AG. f:transcript strand, b:both strands, n:don't match GT-AG [n]
#   Input/Output:
#     -a           output in the SAM format (PAF by default)
#     -Q           don't output base quality in SAM
#     -R STR       SAM read group line in a format like '@RG\tID:foo\tSM:bar' []
#     -c           output CIGAR in PAF
#     -S           output the cs tag in PAF (cs encodes both query and ref sequences)
#     -t INT       number of threads [3]
#     -K NUM       minibatch size [200M]
#     --version    show version number
#   Preset:
#     -x STR       preset (recommended to be applied before other options) []
#                  map10k/map-pb: -Hk19 (PacBio/ONT vs reference mapping)
#                  map-ont: -k15 (slightly more sensitive than 'map10k' for ONT vs reference)
#                  asm5: -k19 -w19 -A1 -B19 -O39,81 -E3,1 -s200 -z200 (asm to ref mapping; break at 5% div.)
#                  asm10: -k19 -w19 -A1 -B9 -O16,41 -E2,1 -s200 -z200 (asm to ref mapping; break at 10% div.)
#                  ava-pb: -Hk19 -w5 -Xp0 -m100 -g10000 -K500m --max-chain-skip 25 (PacBio read overlap)
#                  ava-ont: -k15 -w5 -Xp0 -m100 -g10000 -K500m --max-chain-skip 25 (ONT read overlap)
#                  splice: long-read spliced alignment (see minimap2.1 for details)
# 
# See `man ./minimap2.1' for detailed description of command-line options.

# Usage: miniasm [options] <in.paf>
# Options:
#   Pre-selection:
#     -R          prefilter clearly contained reads (2-pass required)
#     -m INT      min match length [100]
#     -i FLOAT    min identity [0.05]
#     -s INT      min span [2000]
#     -c INT      min coverage [3]
#   Overlap:
#     -o INT      min overlap [same as -s]
#     -h INT      max over hang length [1000]
#     -I FLOAT    min end-to-end match ratio [0.8]
#   Layout:
#     -g INT      max gap differences between reads for trans-reduction [1000]
#     -d INT      max distance for bubble popping [50000]
#     -e INT      small unitig threshold [4]
#     -f FILE     read sequences []
#     -n INT      rounds of short overlap removal [3]
#     -r FLOAT[,FLOAT]
#                 max and min overlap drop ratio [0.7,0.5]
#     -F FLOAT    aggressive overlap drop ratio in the end [0.8]
#   Miscellaneous:
#     -p STR      output information: bed, paf, sg or ug [ug]
#     -b          both directions of an arc are present in input
#     -1          skip 1-pass read selection
#     -2          skip 2-pass read selection
#     -V          print version number
# 
# See miniasm.1 for detailed description of the command-line options.
