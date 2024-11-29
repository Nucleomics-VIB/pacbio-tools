#!/bin/bash

# scripts: get_SIIe_run_v2.sh
# download run files from bucket
# matches the new folder structure (05-2022)
# Stephane Plaisance (VIB-NC) 2021/12/20; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="2.0, 2022-05-12"

usage='# Usage: get_SIIe_run_v2.sh <args>
# -R <runs_dir (obtained from "gsutil ls gs://gcpi-rvvnc/")>
# -r <run_id (obtained from "gsutil ls gs://gcpi-rvvnc/<runs_dir>")>
# -l <show the list of runs_dir currently present on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

while getopts "R:r:lh" opt; do
  case $opt in
    R) rundir=${OPTARG} ;;
    r) runid=${OPTARG} ;;
    l) echo "# Runs data currently available on the bucket";
    		gsutil ls gs://gcpi-rvvnc/${rundir:-""}/${runid:-""};
			exit 0 ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# test if minimal arguments were provided
if [ -z "${rundir}" ]
then
   echo "# no run folder name provided!"
   echo "${usage}"
   exit 1
fi

if [ -z "${runid}" ]
then
   echo "# no runID folder name provided!"
   echo "${usage}"
   exit 1
fi

# create local folder
mkdir -p ${rundir}/${runid} && cd ${rundir}/${runid}

# get run folder
echo -e "\n# getting run data"
gsutil -m rsync -r "gs://gcpi-rvvnc/${rundir}/${runid}/" .

echo -e "\n\n# copy done"
