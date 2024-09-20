#!/bin/bash

# hifiBam2metrics_v13.sh: 
# parse a PB HIFI BAM file (PB v13)
# https://pacbiofileformats.readthedocs.io/en/13.0/BAM.html
# extract molecule ID, read length, pass number,and quality score
# save results to a text table (TSV) for stats in R
# for multiplexed data, run with: 'find . -name "*.bam" -exec hifiBam2metrics_v13.sh {} \;'
# or in parallel: 'find . -name "*.bam" | parallel -j 4 hifiBam2metrics.sh {}'
# followed by: 'find . -name "*_hifi_metrics.txt" | parallel -j 4 sequel_hifi_plots.R -i {}'
#
# Stéphane Plaisance - VIB-NC 2024-09-09 v1.3
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam
# GNU awk for parsing sam data

if [ -z "${1}" ]
then
	echo "# provide a hifi bam file to be parsed!"
	exit 1
else
	hifibam=$1
fi

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )
$( hash awk 2>/dev/null ) || ( echo "# awk not found in PATH"; exit 1 )

# Define field numbers for future modifications
PASS_NUM_FIELD=20
QUALITY_FIELD=22

# see data example bellow (truncated at 80 columns)

samtools view ${hifibam} | \
  awk -v pass_num_field=${PASS_NUM_FIELD} -v quality_field=${QUALITY_FIELD} 'BEGIN{FS="\t"; OFS=","; 
           print "Mol.ID","len","npass","Accuracy";
           }
	{split($1,hd,"/");
	  if( $(pass_num_field) ~ /np:i:/ ){
            split($(pass_num_field),np,":");
        };
      if( $(quality_field) ~ /rq:f:/ ){
            split($(quality_field),rq,":");
            rqual=-10*log(1-rq[3])/log(10);
            if (rqual ~ /+inf/){
                rqual = 60;
            };
        };
	print hd[2],length($10),np[3],rq[3] 
	}' > $(basename ${hifibam%%.bam})_hifi_metrics.txt


exit 0

# samtools view <hifi_reads.bam> | head -1 | transpose -t | cat -n
# 
#    1  m84247_240808_093041_s1/47453479/ccs/fwd
#    2  4
#    3  *
#    4  0
#    5  255
#    6  *
#    7  *
#    8  0
#    9  0
#   10  CCTGCCGCACGCAGCGCTCCCTGACGTTCGGGTCGATCTTCTTCGGCATGGCTTGCATCCTTCC
#   11  IIIDDIIIIIIIDIIIIIIIIIIIIIIII<IIIIIIIIIIIIII<IIIIDIIIIIIIIIIIIII
#   12  ML:B:C,37,13,13,234,151,238,45,142,56,17,24,109,46,48,12,80,52,7
#   13  MM:Z:C+m?,3,1,1,4,0,0,2,9,4,4,3,1,1,0,2,3,12,3,7,3,0,4,4,10,1,4,
#   14  ac:B:i,7,0,7,0
#   15  bx:B:i,16,8
#   16  ec:f:6.98415
#   17  ff:i:4
#   18  ip:B:C,41,37,23,26,29,12,24,16,37,20,27,22,24,24,41,14,40,13,27,
#   19  ma:i:0
##   20  np:i:7
#   21  pw:B:C,22,51,8,12,26,14,46,27,26,25,19,47,21,30,28,49,23,11,67,3
##   22  rq:f:0.991924
#   23  sn:B:f,13.194,18.5403,4.81555,8.55939
#   24  we:i:10296639
#   25  ws:i:1057479
#   26  zm:i:47453479
#   27  qs:i:16
#   28  qe:i:15366
#   29  bc:B:S,0,0
#   30  bq:i:68
#   31  cx:i:12
#   32  bl:Z:ATCGTGCGACGAGTAT
#   33  bt:Z:ATACTCGG
#   34  ql:Z:III<IIIIIIII<III
#   35  qt:Z:IIIIDI+I
#   36  ls:B:C,137,162,98,99,164,48,45,45,48,162,98,113,68,163,99,115,97
#   37  RG:Z:a84203a5/0--0
