#!/bin/bash

# delete_SQ_data.sh
# delete content of a Sequel run folder as the 'smrtanalysis' user
# Stephane Plaisance (VIB-NC) 2018/01/26; v1.0
# visit our Git: https://github.com/Nucleomics-VIB

# check parameters for your system
version="1.1, 2018_05_09"
usage='# Usage: delete_SQ_data.sh
# script version '${version}'
## input files
# [required: -f <run-folder> (runID/smartcell path to delete)]
# [-r <data root (default to <$SMRT_DATA>)]
# [-l <show the list of folders currently present on the server>]
# [-h for this help]'

# SMRTlink user
pbuser="smrtanalysis"

while getopts "f:r:lh" opt; do
	case $opt in
		f) foldername=${OPTARG} ;;
		r) datapath=${OPTARG} ;;
		l) echo "# Data currently in ${datapath:-"$SMRT_DATA"}:";
			tree -I "000" -L 3 ${datapath:-"$SMRT_DATA"}; 
			exit 0 ;;
		h) echo "${usage}" >&2; exit 0 ;;
		\?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
		*) echo "this command requires arguments, try -h" >&2; exit 1 ;;
	esac
done

if [ $# -lt 1 ]; then
  echo "# please provide the name of the Sequel run folder to empty"
  exit 0
fi

folderpath=${datapath}/${foldername}
date=$(date +%Y%m%d)

echo "Preparing to delete the content of ${folderpath}"

read -r -p "Are you sure? [y/N] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]
then
  if [ -d "${folderpath}" ]
  then
    echo "enter the password for ${pbuser}"
    su -c "rm -rf ${folderpath}/* && touch ${folderpath}/deleted_${date}" ${pbuser}
  else
    echo "# folder not found in the Sequel data path:"
    tree -I "000" -L 2 ${datapath}
    exit 1
  fi
else
  echo "# not done, aborting!"
  exit 0
fi
