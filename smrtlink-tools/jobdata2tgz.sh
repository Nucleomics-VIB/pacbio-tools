#!/bin/bash

# create archive from Sequel JOB
# script name: jobdata2tgz.sh
# Requirements:
# run this script on a unix system with mounted Sequel primary storage (SMRT_Link in our case)
# run folders are expected in the SMRT_DATA root (define it)
# optional: pigz required to speed up archiving files together with pv to monitor the process
# standard with gzip and one thread
# add --dereference to add original files instead of symlinks
#
# Stephane Plaisance (VIB-NC+BITS) 2018/04/13; v1.0
#
# adapted from rundata2tgz.sh
# requires pigz for fast compression
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.4, 2020_09_25"
usage='# Usage: jobdata2tgz.sh
# script version '${version}'
## input files
# [required: -i <job-folder> (name of the run folder containing the SMRTLink job)]
# [-o <output folder ($NCDATA|$GCDATA; default to <$GCDADA>)]
# [-S <JOB data root (default to <$SMRT_JOBS>)]
# [-p <use pigz and 8 threads (default is to use gzip)>)]
# [-l <show the list of jobs currently present on the server>]
# [-h for this help]'

while getopts "i:o:S:plh" opt; do
	case $opt in
		i) jobfolder=${OPTARG} ;;
		o) outpath=${OPTARG} ;;
		p) usepigz=1 ;;
		l) echo "# Job data currently in ${jobdataroot:-"$SMRT_JOBS"}:";
			ls ${dataroot:-"$SMRT_JOBS"};
			exit 0 ;;
		S) jobdataroot=${OPTARG} ;;
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

# check compressor
if [ -n "$usepigz" ]; then
	$( hash pigz 2>/dev/null ) || ( echo "# pigz not found in PATH, please install"; exit 1 )
	$( hash pv 2>/dev/null ) || ( echo "# pv not found in PATH, please install"; exit 1 )
else
	$( hash gzip 2>/dev/null ) || ( echo "# gzip not found in PATH"; exit 1 )
fi

# check input defined
testvariabledef "${jobfolder}" "-i"

# check data folder
job_data_folder=${jobdataroot:-"$SMRT_JOBS"}

# check runfolder with leading zero's
# job_folder=$(printf "%010d" ${jobfolder})
job_folder=${jobfolder}
testfolderexist "${job_data_folder}/${job_folder}" "-i <job-folder-name (in ${job_data_folder})>"

# check output folder
archive_path=${outpath:-"$GCDATA"}
testfolderwritable "${archive_path}" "-o <output_folder>"

# archive name
archive_file="job_"$(basename ${job_folder}).tgz

# create archive (dereference/follow symlinks)
echo "# creating archive from: ${job_data_folder}/${job_folder}"

curdir=$(pwd)

if [ -n "$usepigz" ]; then
	# use pigz for speed and pv to monitor the process
	cd ${job_data_folder} && \
	tar --dereference -cf - ${job_folder} | \
		pv -p -s $(du -sk "${job_data_folder}/${job_folder}" | cut -f 1)k | \
		pigz -p 8 > ${archive_path}/${archive_file} && \
		cd ${curdir}
else
	cd ${job_data_folder} && \
	tar --dereference -czvf \
		${archive_path}/${archive_file} \
		${job_folder} && \
		cd ${curdir}
fi

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
