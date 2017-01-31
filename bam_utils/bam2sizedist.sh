#!/bin/bash

# bam2sizedist.sh
#
# Stéphane Plaisance - VIB-NC-BITS Jan-18-2017 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools locally installed
# GNU awk for parsing

## edit the following paths to point to the right executables (no check done!)
# samtools 1.3_x preferred to the standard 0.19 for speed
samtools1=$BIOTOOLS/samtools/bin/samtools

if [ -z "${1}" ]
then
	echo "# provide a bam file to be parsed!"
	exit 1
else
	inbam=$1
fi

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
	}' > ${inbam%%.bam}_length-dist.txt
			
