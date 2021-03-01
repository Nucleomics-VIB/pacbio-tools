#!/bin/bash

# script name: run_pbcromwell_pb_ccs.sh
# runs a CCS from the terminal for a chosen subread dataset
# the obtained 'outputs' folder contains files necessary for the pb_demux command
#
# REM: uses code from 'pb_get_subread_path.sh -n <subread-Name> to get the subread path
#
# Stephane Plaisance, VIB-NC 2021/02/19; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

SMRTLinkURL="http://localhost:9091/smrt-link"

usage='# Usage: run_pbcromwell_pb_ccs.sh 
# -n <required: subread name read from a -l run>
# -j <opt: run using json config (default using args>)
# -t <opt: threads per job (default 6)>
# -o <opt: output base folder (default ccs_out - should not exist!)>
# -l => lists the subread names of all available datasets and barcode sets
# [-h for this help]
# script version '${version}

while getopts "n:t:o:jlh" opt; do
  case $opt in
    l) echo "# SMRTLink available subread sets:" ;
       GET ${SMRTLinkURL}/datasets/subreads | jq .[] | jq .name ;
       exit 0 ;;
    n) name=${OPTARG} ;;
    j) json=True;;
    t) opt_nthr=${OPTARG};;
    o) opt_outdir=${OPTARG};;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# optional parameters

# output folder
outdir=${opt_outdir:-"ccs_out"}

# threads per job, default 6 (10 jobs => 60 threads of the available 88)
nthr=${opt_nthr:-6}

# test if outdir exists
if [ -e "${outdir}" ]
then
	echo "! # ${outdir} folder already exists, please rename or delete it"
	echo "${usage}"
	exit 1
fi

# check if name was provided
if [ -z "${name}" ]
then
  echo "! # argument -n needs a value!"
  echo "${usage}"
  exit 1
fi

# -----------------------------------------------------------------------------
# CONFIGURE CROMWELL
# -----------------------------------------------------------------------------

pbcromwell configure \
  --local-job-limit 10 \
  --default-backend Local \
  --output-file $PWD/cromwell.conf

# -----------------------------------------------------------------------------
# CCS
# -----------------------------------------------------------------------------

## other arguments with default values
#  ccs_by_strand = False
#  ccs_max_length = 50000
#  ccs_max_poa_coverage = 0
#  ccs_min_length = 10
#  ccs_min_passes = 3
#  ccs_min_predicted_accuracy = 0.99
#  ccs_min_snr = 2.5
#  ccs_model_args =
#  ccs_polish = True
#  ccs_use_run_design_uuid = False
#  dataset_filters =
#  downsample_factor = 0

ccs_jsonconf="{
  'pb_ccs.eid_subread': '',
  'pb_ccs.ccs_by_strand': false,
  'pb_ccs.ccs_max_length': 50000,
  'pb_ccs.ccs_max_poa_coverage': 0,
  'pb_ccs.ccs_min_length': 10,
  'pb_ccs.ccs_min_passes': 3,
  'pb_ccs.ccs_min_predicted_accuracy': 0.99,
  'pb_ccs.ccs_min_snr': 2.5,
  'pb_ccs.ccs_model_args
  'pb_ccs.ccs_polish': true,
  'pb_ccs.ccs_use_run_design_uuid': false,
  'pb_ccs.dataset_filters': '',
  'pb_ccs.downsample_factor': 0
}"

#  'pb_ccs.nproc': ${nthr}

# get the path of ${name}
subreads=$(GET ${SMRTLinkURL}/datasets/subreads?name=${name} | \
  jq .[] | \
  jq '.path')

if [[ -z ${json+x} ]]
then
  # run optargs version
  cmd="pbcromwell run pb_ccs \
    -e ${subreads} \
     --config $PWD/cromwell.conf \
    --output-dir $PWD/${outdir} \
    -t ccs_by_strand=false \
    -t ccs_max_length=50000 \
    -t ccs_max_poa_coverage=0 \
    -t ccs_min_length=10 \
    -t ccs_min_passes=3 \
    -t ccs_min_predicted_accuracy=0.99 \
    -t ccs_min_snr=2.5 \
    -t ccs_polish=true \
    -t ccs_use_run_design_uuid=false \
    -t downsample_factor=0 \
    -n ${nthr}"
else
  # run config.json version
  # write json conf to local file
  echo ${ccs_jsonconf} | tr "'" "\""> $PWD/ccs.params.json
  
  cmd="pbcromwell run pb_ccs \
    -e ${subreads} \
    --inputs $PWD/ccs.params.json \
    --config $PWD/cromwell.conf \
    --output-dir $PWD/${outdir} \
    -n ${nthr}"
fi

echo -e "# command: ${cmd} \n" | tee $PWD/ccs_log.txt
eval ${cmd} 2>&1 | tee -a $PWD/ccs_log.txt

exit 0

# -----------------------------------------------------------------------------
# pbcromwell --quiet show-workflow-details pb_ccs
# pbcromwell run pb_ccs --help
# -----------------------------------------------------------------------------
# positional arguments:
#   workflow              WDL source
# 
# optional arguments:
#   -h, --help            show this help message and exit
#   --output-dir OUTPUT_DIR
#                         Output directory to run Cromwell in (default:
#                         cromwell_out)
#   --overwrite           Overwrite output directory if it exists (default:
#                         False)
#   -i INPUTS, --inputs INPUTS
#                         Cromwell inputs and settings as JSON (default: None)
#   -e ENTRY_POINTS, --entry ENTRY_POINTS
#                         Entry point dataset (default: [])
#   -n NPROC, --nproc NPROC
#                         Number of processors per task (default: 1)
#   -c MAX_NCHUNKS, --max-nchunks MAX_NCHUNKS
#                         Maximum number of chunks per task (default: None)
#   --target-size TARGET_SIZE
#                         Target chunk size (default: None)
#   --queue QUEUE         Cluster queue to use (default: None)
#   -o OPTIONS, --options OPTIONS
#                         Additional Cromwell engine options, as JSON file
#                         (default: None)
#   -t TASK_OPTIONS, --task-option TASK_OPTIONS
#                         Workflow- or task-level option as key=value string,
#                         specific to the application. May be specified multiple
#                         times for multiple options. (default: [])
#   -b BACKEND, --backend BACKEND
#                         Backend to use for running tasks (default: None)
#   -r MAX_RETRIES, --maxRetries MAX_RETRIES
#                         Maxmimum number of times to retry a failing task
#                         (default: 1)
#   --tmp-dir TMP_DIR     Optional temporary directory for Cromwell tasks (must
#                         exist on all compute hosts) (default: None)
#   --config CONFIG       Java config file for running Cromwell (default: None)
#   --dry-run             Don't execute Cromwell, just write final inputs and
#                         exit (default: True)