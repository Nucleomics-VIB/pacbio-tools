#!/bin/bash

# pb2polymerase.sh: 
# produce polymerase (zmw) reads from scratch and subread BAM files
# produce read counts for all polymerase (zmw) reads
#
# Stéphane Plaisance - VIB-NC-BITS Jan-31-2017 v1.1
# added threads as $2 and fixed error Mar-15-2018 v1.2
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools for parsing bam
# pacbio bam2bam for merging scraps and subreads BAM files

# check if requirements are present
$( hash samtools 2>/dev/null ) || ( echo "# samtools not found in PATH"; exit 1 )
$( hash bam2bam 2>/dev/null ) || ( echo "# pacBio bam2bam not found in PATH"; exit 1 )

# number of parallel threads (x2 -b and -j)
thr=${2:-8}

if [ -z "${1}" ]
then
	echo "# provide a sequel <name>.scraps.bam <threads|8>
	NB: a <name>.subreads.bam BAM files is required at the same location)"
	exit 1
else
	scraps=$1
fi

# play with names
filename=${scraps%.scraps.bam}
title=$(basename ${filename})

# test file is a scraps.bam
if [ "${scraps:${#scraps}-11}" != ".scraps.bam" ]; then
        echo "# name does not match <runID>.scraps.bam"
        exit 1
fi

# check for both inputs
if [ ! -f "${scraps}" ]; then
    echo "${scraps} file not found!";
    exit 1
fi

if [ ! -f "${filename}.subreads.bam" ]; then
    echo "${filename}.subreads.bam file not found!";
    exit 1
fi

cmd="bam2bam -j ${thr} -b ${thr} --zmw --noScraps \
	-o "b2b_"${title} ${filename}.subreads.bam ${scraps}"

echo
echo "# creating polymerase read BAM file"
echo "# ${cmd}"
eval ${cmd}

# check for failure
if [ $? -ne 0 ]; then
	echo "# the bam2bam command failed, please check your inputs"
	exit 1
fi

echo
echo "# counting polymerase reads and saving counts to ${title}_length-dist.txt"
samtools view "b2b_${title}.zmws.bam" | \
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
	}' > "b2b_${title}.zmws_length-dist.txt"
