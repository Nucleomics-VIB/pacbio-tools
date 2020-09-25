#!/bin/bash

# create archive from Sequel RUN
# script name: extractDemuxed.sh
# Requirements:
# run this script on a unix system with mounted Sequel primary storage (SMRT_Link in our case)
# job folder is expected in the SMRT_JOBS root (define it)
#
# Stephane Plaisance (VIB-NC+BITS) 2020/09/25; v1.0
#
# copies fasta files corresponding to the declared barcodes (-n name-file)
# to output_path/jobXXXX_fastX/
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2020_09_25"
usage='# Usage: extractDemuxed.sh
# script version '${version}'
## input files
# [required: -i <job-folder> (number of the job folder containing thedemuxed data)]
# [-n <name-file (csv file with fbc--rbc,sample-name rows)>]
# [-o <output path ($NCDATA|$GCDATA|$NCLVS/Runs/PacBio/2019-03; default to <$NCDADA>)]
# [-J <data root (default to <$SMRT_JOBS>)]
# [-q <also copy fastq (default=NOT)]
# [-h for this help]'

$( hash pigz 2>/dev/null ) || ( echo "# pigz not found in PATH"; exit 1 )

while getopts "i:n:o:J:h" opt; do
	case $opt in
		i) jobfolder=${OPTARG} ;;
		n) namefile=${OPTARG} ;;
		o) outpath_opt=${OPTARG} ;;
		J) jobroot_opt=${OPTARG} ;;
		h) echo "${usage}" >&2; exit 0 ;;
		\?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
		*) echo "this command requires arguments, try -h" >&2; exit 1 ;;
	esac
done

#########################
###### functions ########
#########################
function testvariabledef ()
{
if [ -z "${1}" ]
then
   echo "! # argument ${2} needs a value!"
   echo "${usage}"
   exit 1
else
	return 0
fi
}

function testfolderexist ()
{
if [ ! -d "${1}" -a ! -h "${1}" ]
then
	echo "! # ${1} folder not found!"
	echo "# provide it with ${2}"
	exit 1
else
	return 0
fi
}

function testfilexist ()
{
if [ ! -f "${1}" ]
then
	echo "! # ${1} file not found!"
	echo "# provide it with ${2}"
	exit 1
else
	return 0
fi
}

function testfolderwritable ()
{
if [ ! -w "${1}" ]
then
	echo "! # ${1} folder not found or not writable for the current user!"
	echo "# provide it with ${2}"
	exit 1
else
	return 0
fi
}

#############################
# test inputs
#############################

# check data folder
jobroot=${jobroot_opt:-"$SMRT_JOBS"}

# check jobfolder defined
testvariabledef "${jobfolder}" "-i"

# check jobfolder
testfolderexist "${jobroot}/${jobfolder}" "-i <job-folder-name (in ${jobroot})>"

# check namefile defined
testvariabledef "${namefile}" "-n"

# check jobfolder
testfilexist "${namefile}" "-n <name-file>"

# check output folder
outpath=${outpath_opt:-"$NCDATA"}
testfolderwritable "${outpath}" "-o <output_folder>"

# create subfolder
outdir=${outpath}/demux-job-$(basename ${jobfolder})_reads
mkdir -p ${outdir}

# copy name file to output folder
cp ${namefile} ${outdir}/

# send copy of all outputs to logfile
exec > >(tee ${outdir}/runlog.txt)
# also capture stderr
exec 2>&1

echo "VIB Nucleomics Core; $(date)"
echo "PacBio demultiplexed data"
echo
echo "# copying csv summary"
cp ${jobroot}/${jobfolder}/outputs/barcode_summary.csv ${outdir}/

# fetch fasta files (and fastq if -q)

# loop through pairs
while IFS=',' read -r -a res; do
  # copy file and rename
  if [ $res ]; then
  echo "# copying bam for ${res[0]} with new name: ${res[1]}"
  cp $(find -L ${jobroot}/${jobfolder}/cromwell-job \
    -type f -name lima.${res[0]}.bam) \
    ${outdir}/lima.${res[1]}.bam
  cp $(find -L ${jobroot}/${jobfolder}/cromwell-job \
    -type f -name lima.${res[0]}.bam.pbi) \
    ${outdir}/lima.${res[1]}.bam.pbi
  fi
done < ${namefile}

# add removed reads too
echo
echo "# copying lima.removed.bam leftover reads "
cp $(find -L ${jobroot}/${jobfolder}/cromwell-job -type f -name lima.removed.bam*) \
	${outdir}/

# convert to fasta and fastq
echo
echo "# creating fastq and fasta versions "
for b in ${outdir}/*.bam; do
  bam2fastq ${b} -o ${b%.bam}_Q20
  bam2fasta ${b} -o ${b%.bam}_Q20
done

# report fasta sizes
echo
echo "# the resulting files have a size of (:sequences)"
zgrep -c "^>" ${outdir}/*.fasta.gz | sed -e 's|'"${outdir}/"'||'

