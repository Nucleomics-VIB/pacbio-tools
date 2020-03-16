#!/bin/bash
# script name: run_wgtb2_pb.sh <reads> <genome-size> <prefix> <platform> <thr>
# optimized for Sequel reads
# from https://github.com/ruanjue/wtdbg2
# assemble reads using wdbg2
#
# Stephane Plaisance (VIB-NC) 2020/03/16; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="1.0, 2020_03_16"

reads=${1}
genomesize=${2:-"12.5m"}
prefix=${3:-"wdbg2_asm/$(basename ${reads%.fq.gz})"}
platform=${4:-"sq"}
mm2x=${5:-"map-pb"}
thr=${6:-84}
thr2=$((${thr}/10))

# create folder t store all results
mkdir -p $(dirname ${prefix})

# assemble long reads
wtdbg2 -x ${platform} -g ${genomesize} -i ${reads} -t ${thr} -fo ${prefix}

# derive consensus
wtpoa-cns -t ${thr} -i ${prefix}.ctg.lay.gz -fo ${prefix}.raw.fa

# polish consensus, not necessary if you want to polish the assemblies using other tools
minimap2 -t ${thr} -ax ${mm2x} -r2k ${prefix}.raw.fa ${reads} | \
	samtools sort -@ ${thr2} >${prefix}.bam

samtools view -F0x900 ${prefix}.bam | \
	wtpoa-cns -t ${thr} -d ${prefix}.raw.fa -i - -fo ${prefix}.cns.fa

# Addtional polishing using Illumina paired reads
# reads_1=<path to forward reads>
# reads_2=<path to reverse reads>
# bwa index ${prefix}.cns.fa
# bwa mem -t ${thr} ${prefix}.cns.fa ${reads_1} ${reads_1} | \
#	samtools sort -O SAM | \
#	wtpoa-cns -t ${thr} -x sam-sr -d ${prefix}.cns.fa -i - -fo ${prefix}.PE-polished.fa
