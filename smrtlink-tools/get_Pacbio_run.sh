#!/bin/bash

# script: get_Pacbio_run.sh
# download run files from bucket
# matches the new folder structure (05-2022)
# Stephane Plaisance (VIB-NC) 2021/12/20; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB
#
# transitioned from gsutil to gcloud storage (2026-03-20)
# ref: https://cloud.google.com/storage/docs/gsutil-transition-to-gcloud

version="3.0, 2026-03-20"

usage='# Usage: get_Pacbio_run.sh <args>
# -R <runs_dir (default: "runs")>
# -r <run_id (obtained from "-l" or "gcloud storage ls gs://gcpi-rvvnc/<runs_dir>")>
# -l <show the current list of runs_dir on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

# Set default value for rundir
rundir="runs"

while getopts "R:r:lh" opt; do
  case $opt in
    R) rundir="${OPTARG}" ;;
    r) runid="${OPTARG}" ;;
    l) listmode=1 ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# List mode: all options are now parsed
if [ -n "${listmode}" ]; then
  echo "# Runs data currently available on the bucket"
  if [ -n "${runid}" ]; then
    # list files and subfolders inside the specified run folder
    gcloud storage ls "gs://gcpi-rvvnc/${rundir}/${runid}/"
  else
    # list run folders only
    gcloud storage ls "gs://gcpi-rvvnc/${rundir}/"
  fi
  exit 0
fi

# Transfer mode requires runid
if [ -n "${runid}" ]; then
  # create local folder
  mkdir -p "${runid}" && cd "${runid}" || exit 1

  # get run folder
  # gcloud storage rsync is parallel by default (no -m flag needed)
  echo -e "\n# getting run data"
  gcloud storage rsync --recursive "gs://gcpi-rvvnc/${rundir}/${runid}/" .
  echo -e "\n\n# copy done"
fi
