#!/bin/bash

# scripts: get_SIIe_run.sh
# download run files from bucket
#
# Stephane Plaisance (VIB-NC) 2021/12/20; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="1.0, 2020-12-20"

usage='# Usage: get_SIIe_run.sh <args>
# -R <run_name (obtained from "gsutil ls gs://gcpi-rvvnc/")>
# -r <run_id (obtained from "gsutil ls gs://gcpi-rvvnc/<run_name>")>
# -s <smart-cell_id (obtained from "gsutil ls gs://gcpi-rvvnc/<run_name><run_id>")>
# -l <show the list of run folders currently present on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

while getopts "R:r:s:lh" opt; do
  case $opt in
    R) rundir=${OPTARG} ;;
    r) runid=${OPTARG} ;;
    s) scid=${OPTARG} ;;
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

if [ -z "${scid}" ]
then
   echo "# no SmartCell ID folder name provided!"
   echo "${usage}"
   exit 1
fi

# create local folder
mkdir -p ${rundir}/${runid}/${scid} && cd ${rundir}/${runid}/${scid}

# get run folder
echo -e "\n# getting run data"
gsutil -m rsync -r "gs://gcpi-rvvnc/${rundir}/${runid}/${scid}/" .

echo -e "\n\n# copy done"
