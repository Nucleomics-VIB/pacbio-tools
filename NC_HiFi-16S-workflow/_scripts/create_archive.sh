#!/bin/bash

# create tgz archive from the final_result folder
# also compute and test md5sum and list the archive content in a file
# takes 4 positional arguments:
# $1: path to folder to be archived (excluded)
# $2: name of the folder to be archived
# $3: thread count for pigz
# $4: prefix of the archive (.tgz excl)
#
# or run "docker run --rm -v $PWD:$PWD ${DOCKER_IMAGE} create_archive.sh ${outfolder} ${final_results} ${thr} ${pfx}"
# Stephane Plaisance (VIB-NC) 2024/06/21; v1.0

cd ${1}
log="tar_cmd_issues.txt"

cmd="{ tar cvfh - ${2} \
  | pigz -p ${3} \
  | tee >(md5sum > ${4}.tgz_md5.txt) > ${4}.tgz; \
  } 2> ${4}_content.txt"

echo "# ${cmd}" | tee tar_command_from_script.txt
eval ${cmd} 2>> ${log}

echo -e "# archive ${4}.tgz and md5sum ${4}.tgz_md5.txt were created in ${1}" | tee -a ${log}

# fix file path in md5sum
sed -i "s|-|${4}.tgz|g" ${4}.tgz_md5.txt 2>> ${log}

echo -e "\n# Checking md5sum" 2>> ${log}

md5sum -c ${4}.tgz_md5.txt | tee -a ${4}.tgz_md5-check.txt 2>> ${log}
