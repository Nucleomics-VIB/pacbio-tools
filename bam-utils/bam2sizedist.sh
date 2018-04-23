#!/bin/bash

# bam2sizedist.sh: 
# parse a PB BAM file
# extract molecule ID, read length, barcode information, and polymerase coordinates
# save results to a text table (TSV) for stats in R
#
# Stéphane Plaisance - VIB-NC-BITS Jan-31-2017 v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam
# GNU awk for parsing sam data

if [ -z "${1}" ]
then
	echo "# provide a bam file to be parsed!"
	exit 1
else
	inbam=$1
fi

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )
$( hash awk 2>/dev/null ) || ( echo "# awk not found in PATH"; exit 1 )

# read_name: m54094_180411_025859/4260449/16464_22394
#                 {movieName}/{holeNumber}/{qStart}_{qEnd}
# h[1] = movieName = deviceID_yymmdd_hhmmss (m54094_180411_025859)
# h[2] = ZMWID (4260449)
# h[3] = qS_qE (16464_22394)

samtools view ${inbam} | \
awk 'BEGIN{FS="\t"; OFS=","; print "Mol.ID","start","end","FBC","RBC","BCQ","len"}
	{split($1,hd,"/");
	split(hd[3],co,"_");
	if( $12 ~ /bc:B:S/ ){
		split($12,bc,":"); 
		split(bc[3],id,","); 
		split($13,q,":"); 
		print hd[2],co[1],co[2],id[2],id[3],q[3],length($10) 
		} else {
			print hd[2],co[1],co[2],"na","na","na",length($10)
			}
	}' > $(basename ${inbam%%.bam})_length-dist.txt
