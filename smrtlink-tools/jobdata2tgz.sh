#!/bin/bash

# create archive from Sequel JOB
# script name: jobdata2tgz.sh
# Requirements:
# run this script on a unix system with mounted Sequel primary storage (SMRT_Link in our case)
# run folders are expected in the SMRT_DATA root (define it)
# pigz required to speed up archiving files
#
# Stephane Plaisance (VIB-NC+BITS) 2018/04/13; v1.0
#
# adapted from rundata2tgz.sh
# requires pigz for fast compression
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2018_04_13"
usage='# Usage: jobdata2tgz.sh
# script version '${version}'
## input files
# [required: -i <job-folder> (name of the run folder containing the SMRTLink job)]
# [-o <output folder ($NCDATA|$GCDATA; default to <$GCDADA>)]
# [-S <JOB data root (default to <$SMRT_DATA/000>)]
# [-l <show the list of jobs currently present on the server>]
# [-h for this help]'

$( hash pigz 2>/dev/null ) || ( echo "# pigz not found in PATH"; exit 1 )

while getopts "i:o:S:lh" opt; do
  case $opt in
    i) jobfolder=${OPTARG} ;;
    o) outpath=${OPTARG} ;;
    l) echo "# Data currently in ${dataroot:-"$SMRT_DATA/000"}:";
        ls ${dataroot:-"$SMRT_DATA/000"};
        exit 0 ;;
    S) dataroot=${OPTARG} ;;
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

# check input defined
testvariabledef "${jobfolder}" "-i"

# check data folder
data_folder=${dataroot:-"$SMRT_DATA/000"}

# check runfolder
job_folder=${jobfolder}
testfolderexist "${data_folder}/${job_folder}" "-i <job-folder-name (in ${data_folder})>"

# check output folder
archive_path=${outpath:-"$GCDATA"}
testfolderwritable "${archive_path}" "-o <output_folder>"

# archive name
archive_file="job_"$(basename ${job_folder}).tgz

# create archive (dereference/follow symlinks)
echo "# creating archive from: ${data_folder}/${job_folder}"
tar --use-compress-program="pigz" \
	--exclude "*.las" \
	-C ${data_folder} \
	-h -cvf \
	${archive_path}/${archive_file} \
	${job_folder}

if [ $? -eq 0 ]; then
	echo
	echo "# archive was created successfully, now checksumming"
	md5sum ${archive_path}/${archive_file} | sed -r "s/ .*\/(.+)/  \1/g" \
		> ${archive_path}/${archive_file}_md5.txt && \
		echo; echo "# checksum saved as: ${archive_path}/${archive_file}_md5.txt" && \
		du -a -h --max-depth=1 ${archive_path}/${archive_file}* | \
		sort -hr ; cat ${archive_path}/${archive_file}_md5.txt
else
    echo
    echo "# something went wrong, please have a check!"
    exit 1
fi

# checking the md5sum 
if [ $? -eq 0 ]; then
	echo
	echo "# verifying the checksum against the archive"
	cd ${archive_path} && md5sum -c ${archive_file}_md5.txt 2>&1 | \
	 tee -a ${archive_file}_md5-test.txt && \
	 cd -
else
    echo
    echo "# something went wrong, please have a check!"
    exit 1
fi
