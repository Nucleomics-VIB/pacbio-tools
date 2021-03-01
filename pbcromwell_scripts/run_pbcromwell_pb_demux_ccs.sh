#!/bin/bash

# script name: run_pbcromwell_pb_demux_ccs.sh
# runs a CCS from the terminal for a chosen subread dataset
# runs demultiplexing of the obtained CCS data
#
# REM: uses code from 'pb_get_subread_path.sh -n <subread-Name> to get the subread path
#
# Stephane Plaisance, VIB-NC 2021/02/26; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

SMRTLinkURL="http://localhost:9091/smrt-link"

usage='# Usage: run_pbcromwell_pb_demux_ccs.sh 
# -c <required: path to the CCS folder (contains a "outputs" folder)>
# -b <required: barcode set name read from a -l run>
# -s <required: barcode-names.csv file>
# -j <opt: run using json config (default using args>)
# -t <opt: threads per job (default 6)>
# -o <opt: output base folder (default ccs-demux_out - should not exist!)>
# -l => lists the subread names of all available datasets and barcode sets
# [-h for this help]
# script version '${version}

while getopts "c:b:s:t:o:jSh" opt; do
  case $opt in
    l) echo "# SMRTLink available barcode sets:" ;
       GET ${SMRTLinkURL}/datasets/barcodes | jq .[] | jq .name ;
       exit 0 ;;
    c) ccspath=${OPTARG} ;;
    b) barcode_set=${OPTARG};;
    S) opt_sym=True;;
    s) biosamples_csv=${OPTARG};;
    j) json=True;;
    t) opt_nthr=${OPTARG};;
    o) opt_outdir=${OPTARG};;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# required parameters

# check if ccspath was provided
if [ -z "${ccspath}" ]
then
  echo "! # argument -c needs a value!"
  echo "${usage}"
  exit 1
fi

# check if path contains outputs
if [ -d "${ccspath}"/outputs ]
then
	echo "! # ${ccspath} folder does not contain a folder 'outputs'"
	echo "${usage}"
#	exit 1
fi

# check if barcode_set was provided
if [ -z "${barcode_set}" ]
then
  echo "! # argument -b needs a value!"
  echo "# get the list of available barcode sets from a dry run with -l"
  echo "${usage}"
  exit 1
fi

# check if samples was provided
if [ -z "${biosamples_csv}" ]
then
  echo "! # argument -s needs a value!"
  echo "${usage}"
  exit 1
fi

# optional parameters

# output folder
outdir=${opt_outdir:-"ccs-demux_out"}

# threads per job, default 6 (10 jobs => 60 threads of the available 88)
nthr=${opt_nthr:-6}

# test if outdir exists
if [ -e "${outdir}" ]
then
	echo "! # ${outdir} folder already exists, please rename or delete it"
	echo "${usage}"
	exit 1
fi

# check if barcodes are symetric (-S)
if [ -z "${opt_sym}" ]
then
  symetric="false"
else
  symetric="true"
fi

# -----------------------------------------------------------------------------
# CONFIGURE CROMWELL
# -----------------------------------------------------------------------------

pbcromwell configure \
  --local-job-limit 10 \
  --default-backend Local \
  --output-file $PWD/cromwell.conf

# -----------------------------------------------------------------------------
# DEMULTIPLEX
# -----------------------------------------------------------------------------
# NOTE: entry point is ccs output and a barcode set (see below)
# NOTE: samples csv can be passed on through a task option (biosamples_csv)

## other arguments with default values
#   biosamples_csv = None
#   lima_min_score = 0
#   lima_peek_guess = True
#   lima_symmetric_barcodes = True
#   lima_write_unbarcoded = True
#   min_bq_filter = 26
#   new_dataset_name = 
#   pb_test_mode = False
#   use_barcode_uuids = False

demux_jsonconf="{
  'pb_demux_ccs.eid_barcode': '',
  'pb_demux_ccs.eid_ccs': '',
  'pb_demux_ccs.biosamples_csv': '$PWD/${biosamples_csv}',
  'pb_demux_ccs.lima_min_score': 0,
  'pb_demux_ccs.lima_peek_guess': true,
  'pb_demux_ccs.lima_symmetric_barcodes': ${symetric},
  'pb_demux_ccs.lima_write_unbarcoded': true,
  'pb_demux_ccs.min_bq_filter': 26,
  'pb_demux_ccs.new_dataset_name': '',
  'pb_demux_ccs.pb_test_mode': false,
  'pb_demux_ccs.use_barcode_uuids': false
  }"

# get the path of ${name}
barcodes=$(GET ${SMRTLinkURL}/datasets/barcodes?name=${barcode_set} | \
  jq .[] | \
  jq '.path')

# get the path to the final.consensusreadset.xml
ccs=$(find ${ccspath}/outputs -name final.consensusreadset.xml -exec readlink -f {} \;)

if [[ -z ${json+x} ]]
then
  # run optargs version
  echo -e "\n# Currently, only the 'json' method works, re-run with '-j'\n"
  exit 1
else
  # run config.json version
  # write json conf to local file
  echo ${demux_jsonconf} | tr "'" "\""> demux.params.json
  
  cmd="pbcromwell run pb_demux_ccs \
    -e ${barcodes} \
    -e ${ccs} \
    --inputs $PWD/demux.params.json \
    --config $PWD/cromwell.conf \
    --output-dir $PWD/${outdir} \
    -n ${nthr}"
fi

echo -e "# command: ${cmd} \n" | tee $PWD/ccs-demux_log.txt
eval ${cmd} 2>&1 | tee -a $PWD/ccs-demux_log.txt

exit 0

# -----------------------------------------------------------------------------
# pbcromwell --quiet show-workflow-details pb_demux_ccs
# pbcromwell run pb_demux_ccs --help
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