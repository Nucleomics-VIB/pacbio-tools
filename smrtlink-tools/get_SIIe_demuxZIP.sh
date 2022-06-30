#!/bin/bash

# scripts: get_SIIe_demuxZIP.sh
# download demultiplexing ZIP archive from bucket and extarct key files
#
# Stephane Plaisance (VIB-NC) 2022/06/27; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="1.0, 2020-12-20"

usage='# Usage: get_SIIe_demuxZIP.sh <args>
# -r <run_name (obtained from "gsutil ls gs://gcpi-rvvnc/exports")>
# -l <show the list of run folders currently present on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

while getopts "r:lh" opt; do
  case $opt in
    r) rundir=${OPTARG} ;;
    l) echo "# Runs data currently available on the bucket";
                gsutil ls gs://gcpi-rvvnc/exports;
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

# get the archive from the cloud
cmd="gsutil ls gs://gcpi-rvvnc/exports/${rundir}/*.zip"
res=$(eval ${cmd})
zipfile=$(basename ${res})
pfx=${zipfile%.zip}

# get the files
mkdir -p ${rundir}_demux && cd ${rundir}_demux
gsutil cp ${res} .
unzip ${zipfile}
cd ../

# get bam data
mkdir -p bam_data/
find ${pfx} -name "demultiplex.*.bam" -exec cp {} bam_data/ \;

# get fastX data
mkdir -p fastX_data/
find ${pfx} -name "demultiplex.*.hifi_reads.fastq.gz" -exec cp {} fastX_data/ \;

# get demux job data
mkdir -p demux_data
demuxfolder=$(dirname $(find ${pfx} -name "barcode_ccs_summary.csv"))
cp ${demuxfolder}/barcode_ccs_summary.csv demux_data/
cp ${demuxfolder}/bq_histogram.png demux_data/
cp ${demuxfolder}/nreads_histogram.png demux_data/
cp ${demuxfolder}/nreads.png demux_data/
cp ${demuxfolder}/readlength_histogram.png demux_data/

echo -e "\n\n# copy done"
echo

# run demux plotting
echo "# the next logical step would be tu run:"
echo "# barcode_QC.sh -i demux_data/barcode_ccs_summary.csv -p <project#>"
