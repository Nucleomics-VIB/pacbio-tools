#!/bin/bash

# create archive from Sequel RUN
# script name: rundata2tgz.sh
# Requirements:
# run this script on a unix system with mounted Sequel primary storage (SMRT_Link in our case)
# pigz required to speed up archiving files
#
# Stephane Plaisance (VIB-NC+BITS) 2017/01/23; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.0, 2017_01_23"

usage='# Usage: rundata2tgz.sh
# script version '${version}'
## input files
# [required: -i <run-folder> (containing the flow-cell folder)]
# [-f <flowcell name (default <1_A01> for a single-cell run)>]
# [-o <output folder (default to <$SMRT_DOWNLOADS>]
# [-h for this help]'

while getopts "i:f:o:h" opt; do
  case $opt in
    i) runfolder=${OPTARG} ;;
    f) flowcell=${OPTARG} ;;
    o) outpath=${OPTARG} ;;
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
testvariabledef "${runfolder}" "-i"

# check runfolder
run_folder=${runfolder}
testfolderexist "${run_folder}" "-i <path-to-run-folder>"

# set to default if not provided
flow_cell=${flowcell:-"1_A01"}

# check flow-cell folder
flowcell_path=${run_folder}/${flow_cell}
testfolderexist "${flowcell_path}" "-i"

# check output folder
archive_path=${outpath:-"$GCDATA"}
testfolderwritable "${archive_path}" "-o <output_folder>"

# archive name
archive_file=$(basename ${run_folder})-$(basename ${flowcell_path}).tgz

# create archive
echo "# creating archive from: ${run_folder}/${flow_cell}"
tar --use-compress-program="pigz" \
	--exclude "*.h5" \
	--exclude "*.baz" \
	--exclude "*.log" \
	-h -cvf \
	${archive_path}/${archive_file} \
	${run_folder}/${flow_cell}

echo
if [ $? -eq 0 ]; then
	echo "# archive was created successfully, now checksumming"
	md5sum ${archive_path}/${archive_file} > ${archive_path}/${archive_file}_md5.txt && \
	echo; echo "# checksum saved as: ${archive_path}/${archive_file}_md5.txt" && \
	ls -lah ${archive_path}/${archive_file}* ; cat ${archive_path}/${archive_file}_md5.txt
else
    echo "# something went wrong, please have a check!"
fi
