#!/bin/bash

# script name: run_pbcromwell_pb_mv_ccs.sh
# runs a minor variant analysis from the terminal for a chosen ccs+demux folder
#
# Stephane Plaisance, VIB-NC 2021/02/26; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

SMRTLinkURL="http://localhost:9091/smrt-link"
version="1.0, 2021_02_26"

usage='# Usage: run_pbcromwell_pb_mv_ccs.sh 
# -c <required: path to the (demultiplexed-) CCS folder (contains a "outputs" folder)>
# -r <required: SMRTLink reference name read from a -l run>
# -T <required: json reference config file>
# -u <opt: no phasing: default to phasing=True>
# -j <opt: run using json config (default using args>)
# -t <opt: threads per job (default 6)>
# -o <opt: output folder (default mv_ccs_out - should not exist!)>
# -l => lists the names of all available references to use with "-r"
# [-h for this help]
# script version '${version}

while getopts "c:r:T:t:o:ljuh" opt; do
  case $opt in
    l) echo "# SMRTLink available reference sets:" ;
       GET ${SMRTLinkURL}/datasets/references | jq .[] | jq .name
       exit 0 ;;
    c) ccspath=${OPTARG} ;;
    r) refname=${OPTARG} ;;
    T) targetconf=${OPTARG};;
    u) opt_nophasing=1;;
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

# check if path contains the folder 'outputs'
if [[ ! -d "${ccspath}"/outputs ]]
then
	echo "! # ${ccspath} folder does not contain a folder 'outputs'"
	echo "${usage}"
	exit 1
fi

# check if refname was provided
if [ -z "${refname}" ]
then
  echo "! # argument -r needs a value, run with '-l' to list all available references"
  echo "${usage}"
  exit 1
fi

# get path to the reference xml file
reference=$(GET ${SMRTLinkURL}/datasets/references?name=${refname} | \
  jq .[] | \
  jq '.path')

# check if targetconf was provided
if [ -z "${targetconf}" ]
then
  echo "! # argument -T needs a json reference config file"
  echo "${usage}"
  exit 1
fi

# optional parameters

# output folder
outdir=${opt_outdir:-"mv_ccs_out"}
mkdir -p ${outdir}

# threads per job, default 6 (10 jobs => 60 threads of the available 88)
nthr=${opt_nthr:-6}

# check if phasing is required (-u))
if [[ -z ${opt_nophasing+x} ]]
then
  phasing="true"
else
  phasing="false"
fi


# -----------------------------------------------------------------------------
# CONFIGURE CROMWELL
# -----------------------------------------------------------------------------

pbcromwell configure \
  --local-job-limit 10 \
  --default-backend Local \
  --output-file $PWD/cromwell.conf

# -----------------------------------------------------------------------------
# RUN MINOR VARIANT ANALYSIS
# -----------------------------------------------------------------------------
# more info: pbcromwell run --help

# Task Options:
# juliet options provided through -t ...
#   juliet_debug = False
#   juliet_deletion_rate = 0.0
#   juliet_genomic_region = 
#   juliet_maximal_percentage = 100.0
#   juliet_minimal_percentage = 0.1
#   juliet_mode_phasing = True
#   juliet_only_known_drms = False
#   juliet_substitution_rate = 0.0
#   juliet_target_config = none

# get the sorted array of inputs in ${ccspath}/outputs
inputs=( $(find ${ccspath}/outputs \
  -name "*.xml" -not -name "unbarcoded.consensusreadset.xml" \
  -exec readlink -f {} + | sort) )

mv_jsonconf="{
  'pb_mv_ccs.eid_ccs': '',
  'pb_mv_ccs.eid_ref_dataset': '',
  'pb_mv_ccs.juliet_debug': false,
  'pb_mv_ccs.juliet_deletion_rate': 0.0,
  'pb_mv_ccs.juliet_maximal_percentage': 100.0,
  'pb_mv_ccs.juliet_minimal_percentage': 0.1,
  'pb_mv_ccs.juliet_mode_phasing': ${phasing},
  'pb_mv_ccs.juliet_only_known_drms': false,
  'pb_mv_ccs.juliet_substitution_rate': 0.0,
  'pb_mv_ccs.juliet_target_config': '$PWD/${targetconf}'
  }"

# loop through all available demuxed samples
for ccs in ${inputs[@]}; do

  spl=$(basename ${ccs%.consensusreadset.xml})
  pfx=${spl#demultiplex.}

  # test if outdir exists and go to next ccs
  if [ -d "$PWD/${outdir}/mv_${pfx}" ]
  then
    echo "! # ${outdir}/mv_${pfx} folder already exists, please rename or delete it"
    echo "${usage}"
    continue 1
  fi
    
  if [[ -z ${json+x} ]]
  then
    #  using optargs
    cmd="pbcromwell run pb_mv_ccs \
      -e ${ccs} \
      -e ${reference} \
      --output-dir $PWD/${outdir}/mv_${pfx} \
      -t juliet_debug=False \
      -t juliet_deletion_rate=0.0 \
      -t juliet_genomic_region="" \
      -t juliet_maximal_percentage=100.0 \
      -t juliet_minimal_percentage=0.1 \
      -t juliet_mode_phasing=${phasing} \
      -t juliet_only_known_drms=False \
      -t juliet_substitution_rate=0.0 \
      -t juliet_target_config=$PWD/${targetconf} \
      -n ${nthr}"
  else
    # using json config
    # write json conf to local file
    echo ${mv_jsonconf} | tr "'" "\""> mv_ccs.params.json
  
    cmd="pbcromwell run pb_mv_ccs \
      -e ${ccs} \
      -e ${reference} \
      --inputs $PWD/mv_ccs.params.json \
      --config  $PWD/cromwell.conf \
      --output-dir $PWD/${outdir}/mv_${pfx} \
      -n ${nthr}"
  fi

  echo -e "# command: ${cmd} \n" | tee $PWD/${outdir}/mv_${pfx}_log.txt
  eval ${cmd} 2>&1 | tee -a $PWD/${outdir}/mv_${pfx}_log.txt

done

exit 0

# -----------------------------------------------------------------------------
# MORE INFO: MINOR VARIANT ANALYSIS
# -----------------------------------------------------------------------------
# pbcromwell --quiet show-workflow-details pb_mv_ccs
# pbcromwell run pb_mv_ccs --help
# -----------------------------------------------------------------------------
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