#!/bin/bash

# bam_subset_smrt.sh
# create a random subset from a BAM file
# => use each time a new seed to reduce sample overlap
# index and upload the resulting data to SMRT Link
#
# Stéphane Plaisance - VIB-NC-BITS Jan-18-2017 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# SMRT Link server installed with access as encoded below
# Pacbio commands locally available
# Samtools locally installed

## edit the following paths to point to the right executables (no check done!)
# samtools 1.3_x preferred to the standard 0.19 for speed
samtools1=$BIOTOOLS/samtools/bin/samtools
dataset=$SMRT_ROOT/dataset
pbindex=$SMRT_ROOT/pbindex
pbservice=$SMRT_ROOT/pbservice
smrthostname=$SMRT_HOST; # ENV variable defined on the server)

#################################################
########## do not edit below this line ##########

version="1.0, 2017_01_18"

usage='# Usage: bam_subset_smrt.sh -b <input.bam>
# script version '${version}'
# [optional: -o <output_prefix|sample_SS_XXpc>]
# [optional: -s <seed|1>]
# [optional: -f <fraction in %|10>]
# [optional: -t <threads|32>]
# [optional: -S <SMRT-server|"${smrthostname}">]
# [optional: -p <SMRT-port|9091>]
# [-h for this help]'

while getopts "b:o:s:f:t:S:p:h" opt; do
  case $opt in
    b) inbam=${OPTARG} ;;
    o) outpfx=${OPTARG} ;;
    s) rseed=${OPTARG} ;;
    f) fraction=${OPTARG} ;;
    t) threads=${OPTARG} ;;
    S) srvaddr=${OPTARG} ;;
    p) srvport=${OPTARG} ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

# functions
function testexecutable ()
{
if [[ ! -x "$1" ]]
then
	echo "! # ${1} is not executable or absent"
	echo "${usage}"
	exit 1
else
	return 0
fi
}

function testfileexist () 
{
if [ ! -e "${1}" ]
then
	echo "! # ${1} file not set or not found, provide with ${2}"
	echo "${usage}"
	exit 1
else
	return 0
fi
}

########## control arguments ####################
# test executables
testexecutable "${samtools1}"
testexecutable "${dataset}"
testexecutable "${pbservice}"

# test BAM provided
testfileexist "${inbam}" "-b"

# create a random seed between 0 and 99 if not specified
# this allows creating several subsets that do not contains the same reads
seed=${rseed:-$(( RANDOM % 100 ))}
prob=${fraction:-10}
thr=${threads:-32}
smrtaddr=${srvaddr:-${smrthostname}}
smrtport=${srvport:-9091}
outname=${outpfx:-"sample_${seed}_${prob}pc"}

########## do it #################################
# create random subset
cmd="${samtools1} view -@ ${thr} -s "${seed}.${prob}" -b ${inbam} > ${outname}.bam"
echo "# ${cmd}"
eval ${cmd}

if [ $? -ne 0 ] ; then
	echo "! samtools subsetting command failed, please check your parameters"
	exit 1
fi

# create indices
cmd="${samtools1} index ${outname}.bam && ${pbindex} ${outname}.bam"
echo "# ${cmd}"
eval ${cmd}

if [ $? -ne 0 ] ; then
	echo "! bam indexing command(s) failed, please check your parameters"
	exit 1
fi

# prepare xml for import
cmd="${dataset} create --type SubreadSet --name ${outname} ${outname}.xml ${outname}.bam"
echo "# ${cmd}"
eval ${cmd}

if [ $? -ne 0 ] ; then
	echo "! xml creation command failed, please check your parameters"
	exit 1
fi

# import on server
cmd="${pbservice} import-dataset --host ${smrtaddr} --port ${smrtport} ${outname}.xml"
echo "# ${cmd}"
eval ${cmd}
