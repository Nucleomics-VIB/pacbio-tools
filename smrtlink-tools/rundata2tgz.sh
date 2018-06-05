#!/bin/bash

# create archive from Sequel RUN
# script name: rundata2tgz.sh
# Requirements:
# run this script on a unix system with mounted Sequel primary storage (SMRT_Link in our case)
# run folders are expected in the SMRT_DATA root (define it)
# pigz required to speed up archiving files
#
# Stephane Plaisance (VIB-NC+BITS) 2017/01/23; v1.0
#
# 2017-01-26: create archive starting at run folder depth (remove leading path that should be $SMRT_DATA); v1.01
# requires pigz for fast compression
# 2018-01-26: edit listing the repo and add metadata.xml file;  v1.1.3
# 2018-06-05: also save subreads.bam next to archive;  v1.1.4

# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.1.4, 2018_06_05"
usage='# Usage: rundata2tgz.sh
# script version '${version}'
## input files
# [required: -i <run-folder> (name of the run folder containing the flow-cell folder)]
# [-f <flowcell name (default <1_A01> for a single-cell run)>]
# [-o <output folder ($NCDATA|$GCDATA; default to <$GCDADA>)]
# [-S <data root (default to <$SMRT_DATA>)]
# [-b <also copy subreads.bam (default=NOT)]
# [-l <show the list of runs currently present on the server>]
# [-h for this help]'

$( hash pigz 2>/dev/null ) || ( echo "# pigz not found in PATH"; exit 1 )

while getopts "i:f:o:S:lbh" opt; do
	case $opt in
		i) runfolder=${OPTARG} ;;
		f) flowcell=${OPTARG} ;;
		o) outpath=${OPTARG} ;;
		b) bamcopy=1 ;;
		l) echo "# Data currently in ${dataroot:-"$SMRT_DATA"}:";
			tree -a -I "000" -L 3 ${dataroot:-"$SMRT_DATA"};
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
testvariabledef "${runfolder}" "-i"

# check data folder
data_folder=${dataroot:-"$SMRT_DATA"}

# check runfolder
run_folder=${runfolder}
testfolderexist "${data_folder}/${run_folder}" "-i <run-folder-name (in ${data_folder})>"

# set to default if not provided
flow_cell=${flowcell:-"1_A01"}

# check flow-cell folder
flowcell_path=${run_folder}/${flow_cell}
testfolderexist "${data_folder}/${flowcell_path}" "-i"

# check output folder
archive_path=${outpath:-"$GCDATA"}
testfolderwritable "${archive_path}" "-o <output_folder>"

# archive name
archive_file=$(basename ${run_folder})-$(basename ${flowcell_path}).tgz

# create archive (dereference/follow symlinks)
echo "# creating archive from: ${data_folder}/${run_folder}/${flow_cell}"
tar --use-compress-program="pigz" \
	--exclude "*.h5" \
	--exclude "*.baz" \
	--exclude "*.log" \
	-C ${data_folder} \
	-h -cvf \
	${archive_path}/${archive_file} \
	${run_folder}/${flow_cell}

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
	echo "# something went wrong while creating archive, please have a check!"
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
	echo "# something went wrong while checking md5sum, please have a check!"
	exit 1
fi


# optionally copy the subread.bam file
if [ $bamcopy == 1 ]; then
	echo
	echo "# copying the subreads.bam file"

	subreads=$(find "${data_folder}/${run_folder}/${flow_cell}" -name "*.subreads.bam" -print )
	bname=$(basename "${subreads}")
	cp ${subreads} ${archive_path}/${archive_file%.tgz}_${bname}

	if [ $? -eq 0 ]; then
		echo
		echo "# subreads.bam file saved as ${archive_path}/${archive_file%.tgz}_${bname}"
	else
		echo
		echo "# something went wrong while copying subreads.bam, please have a check!"
		exit 1
	fi
fi

# also copy metadata file
echo
echo "# copying the run.metadata.xml file"

metadata=$(find "${data_folder}/${run_folder}/${flow_cell}" -regex ".*\..*.run.metadata.xml" -print )
mname=$(basename "${metadata}")
cp ${metadata} ${archive_path}/${archive_file%.tgz}${mname} && touch ${archive_path}/FLAG_READY4COPY_${archive_file%.tgz}.txt

if [ $? -eq 0 ]; then
	echo
	echo "# run.metadata.xml and flag files copied successfully"
else
	echo
	echo "# something went wrong while copying run.metadata.xml or creating FLAG file, please have a check!"
	exit 1
fi

