#!/bin/bash

# scripts: get_SIIe_demux.sh
# download demultiplexing files from bucket
#
# Stephane Plaisance (VIB-NC) 2021/12/20; v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

version="1.0, 2020-12-20"

usage='# Usage: get_SIIe_demux.sh <args>
# -r <run_name (obtained from "gsutil ls gs://gc-to-nucleomicscore/")>
# -l <show the list of run folders currently present on the server>]
# -h <this help>
# script version '${version}'
# [-h for this help]'

while getopts "r:lh" opt; do
  case $opt in
    r) rundir=${OPTARG} ;;
    l) echo "# Runs data currently available on the bucket";
                gsutil ls gs://gc-to-nucleomicscore/;
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

# create local folder
mkdir -p ${rundir} && cd ${rundir}

# get demux fastx
d="fastX_data"
mkdir -p ${d}
echo -e "\n# getting demultiplexing fastX data"
for q in all_barcodes.fasta.tar.gz all_barcodes.fastq.tar.gz; do
cmd="gsutil ls gs://gc-to-nucleomicscore/${rundir}/**/${q}"
res=$(eval ${cmd})
# get the files
gsutil cp -n ${res} ${d}/
done

# get demux qc data
q="barcode_ccs_summary.csv"
d="demux_data"
mkdir -p ${d}
echo -e "\n# getting demultiplexing data and plots"
cmd="gsutil ls gs://gc-to-nucleomicscore/${rundir}/**/${q}"
res=$(eval ${cmd})
path=$(dirname ${res})
# get the files
gsutil -m rsync ${path} ${d}

# get bam data
q="demultiplex.removed.bam"
d="bam_data"
mkdir -p ${d}
echo -e "\n# getting HiFi / ccs bam data"
cmd="gsutil ls gs://gc-to-nucleomicscore/${rundir}/**/${q}"
res=$(eval ${cmd})
path=$(dirname ${res})
# get the files
gsutil -m rsync ${path} ${d}

echo -e "\n\n# copy done"