#!/bin/bash

# scripts: get_Pacbio_run.sh
# download run files from bucket
# matches the new folder structure (05-2022)
# Stephane Plaisance (VIB-NC) 2021/12/20; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="2.1, 2022-06-18"

usage='# Usage: get_Pacbio_run.sh <args>
# -R <runs_dir (default: "runs")>
# -r <run_id (obtained from "-l" or "gsutil ls gs://gcpi-rvvnc/<runs_dir>")>
# -l <show the current list of runs_dir on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

# Set default value for rundir
rundir="runs"

while getopts "R:r:lh" opt; do
  case $opt in
    R) rundir=${OPTARG} ;;
    r) runid=${OPTARG} ;;
    l) echo "# Runs data currently available on the bucket";
       gsutil ls gs://gcpi-rvvnc/${rundir}/${runid:-""};
       exit 0 ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# Transfer mode requires runid
if [ -n "${runid}" ]; then
  # create local folder
  mkdir -p ${runid} && cd ${runid}

  # get run folder
  echo -e "\n# getting run data"
  gsutil -m rsync -r "gs://gcpi-rvvnc/${rundir}/${runid}/" .

  echo -e "\n\n# copy done"
fi
