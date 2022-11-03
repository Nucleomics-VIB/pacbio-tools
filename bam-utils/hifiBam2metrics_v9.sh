#!/bin/bash

# hifiBam2metrics_v9.sh: 
# parse a PB HIFI BAM file (PB v11)
# https://pacbiofileformats.readthedocs.io/en/11.0/BAM.html
# extract molecule ID, read length, barcode information, and polymerase coordinates
# save results to a text table (TSV) for stats in R
# for multiplexed data, run with: 'find . -name "*.bam" -exec hifiBam2metrics.sh {} \;'
# or in parallel: 'find . -name "*.bam" | parallel -j 4 hifiBam2metrics.sh {}'
# followed by: 'find . -name "*_hifi_metrics.txt" | parallel -j 4 sequel_hifi_plots.R -i {}'
#
# Stéphane Plaisance - VIB-NC-BITS Jan-31-2017 v1.2
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

# see data example bellow (truncated at 80 columns)

samtools view ${hifibam} | \
awk 'BEGIN{FS="\t"; OFS=","; 
           print "Mol.ID","len","npass","Accuracy";
           }
	{split($1,hd,"/");
	if( $19 ~ /np:i:/ ){
		split($19,np,":");
		};
	if( $23 ~ /rq:f:/ ){
		split($23,rq,":")
		rqual=-10*log(1-rq[3])/log(10);
        if (rqual ~ /+inf/){
            rqual = 60;
            };
		};
	print hd[2],length($10),np[3],rq[3] 
	}' > $(basename ${hifibam%%.bam})_hifi_metrics.txt


exit 0

#      1	m64279e_220909_132350/330222/ccs
#      2	4
#      3	*
#      4	0
#      5	255
#      6	*
#      7	*
#      8	0
#      9	0
#     10	TGGTGCTGAAGTACAAGACTGTGGATTACTGGTTTCTGAGATTTCCAGATTGCCGTAGCGGCACGAACATAACGCCATGG
#     11	~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ud&X1%4j~~~~~~|~~~~~~~~~~~~~~~~~~~~~~~
#     12	ML:B:C,191,208,25,55,24,5,27,12,227,8,0,0,96,108,37,56,6,236,5,8,72,5,1,44,17,22
#     13	MM:Z:C+m,8,0,1,1,7,4,9,3,4,9,6,1,3,1,2,2,8,0,1,2,3,3,10,15,15,5,1,0,4,8,2,4,1,0,
#     14	ac:B:i,20,0,20,0
#     15	bx:B:i,16,16
#     16	ec:f:19.6699
#     17	fi:B:C,25,18,15,15,7,9,9,48,10,12,16,12,8,7,12,37,18,21,12,5,13,9,8,15,12,8,11,2
#     18	fn:i:10
#     19	fp:B:C,14,27,42,14,18,25,8,30,20,14,25,26,12,11,15,17,20,29,16,12,42,25,26,28,15
#     20	ma:i:0
#     21	np:i:19
#     22	ri:B:C,35,12,26,28,43,39,60,10,7,9,20,11,5,8,6,9,10,10,5,16,123,113,8,7,8,10,8,1
#     23	rn:i:6
#     24	rp:B:C,29,28,31,42,18,36,40,20,27,28,30,9,17,21,51,35,15,75,17,14,25,34,11,28,18
#     25	rq:f:0.99956
#     26	sn:B:f,10.0789,14.8689,3.46528,6.38052
#     27	we:i:10681752
#     28	ws:i:255
#     29	zm:i:330222
#     30	qs:i:16
#     31	qe:i:4849
#     32	bc:B:S,38,38
#     33	bq:i:100
#     34	cx:i:12
#     35	bl:Z:CATGTATGTCGAGTAT
#     36	bt:Z:ATACTCGACATACATG
#     37	ql:Z:~~~~~~~~~~~~~~~~
#     38	qt:Z:~~~~~~~~~~~~~~~~
#     39	ls:B:C,134,162,98,99,166,51,56,45,45,51,56,162,98,113,100,164,108,101,97,100,134
#     40	RG:Z:192801f3/38--38
