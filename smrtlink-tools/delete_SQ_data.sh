#!/bin/bash

# delete content of a Sequel run folder as the 'smrtanalysis' user
# Stephane Plaisance (VIB-NC) 2018/01/26; v1.0
# visit our Git: https://github.com/Nucleomics-VIB

if [ $# -lt 1 ]; then
  echo "# please provide the name of the Sequel run folder to empty"
  exit 0
fi

pbuser="smrtanalysis"
datapath=/data/pacbio/sequel
foldername=$1
folderpath=${datapath}/${foldername}
date=$(date +%Y%m%d)

# list data if -l provided
if [[ $1 == "-l" ]]
then
  tree -I "000" -L 3 ${datapath}
  exit 0
fi

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
    ls ${datapath}
  fi
else
  "not done, aborting!"
fi
