#!/bin/bash

# subreadsextract.sh
# extract subreads.bam from SequelRunFolder.tgz archive and rename it by the archive prefix
#
# Stephane Plaisance VIB-NC 2018_06_05 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements: tar with -O option

# input
tgz_archive=$1

if [ -z "${tgz_archive}" ]; then
	echo "# needs a SequelRunFolder.tgz archive as input"
	exit 1
fi

base=$(basename ${tgz_archive%.tgz})

# list archive and find subreads.bam
target=$(tar -ztvf ${tgz_archive} | grep ".subreads.bam$" | awk '{print $NF}')
target_base=$(basename ${target})

echo "# extracting ${target_base}"
#tar --strip-components= -xf ${tgz_archive} ${target} && mv ${target_base} ${base}_${target_base}

tar -xOf ${tgz_archive} ${target} > ${base}_${target_base}
