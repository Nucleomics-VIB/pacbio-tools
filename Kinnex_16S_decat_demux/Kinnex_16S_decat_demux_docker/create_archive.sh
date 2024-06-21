#!/bin/bash

# called from the main script
# TAR_CMD="docker run --rm -v $PWD:$PWD ${DOCKER_IMAGE} create_archive.sh ${outfolder} ${final_results} ${thr} ${pfx}"
# Stephane Plaisance (VIB-NC) 2024/06/21; v1.0

log="tar_cmd_issues.txt"
cd ${1}

cmd="{ tar cvfh - ${2} \
  | pigz -p ${3} \
  | tee >(md5sum > ${4}.tgz_md5.txt) > ${4}.tgz; \
  } 2> ${4}_content.txt"

echo "# ${cmd}" | tee tar_command_from_script.txt
eval ${cmd} 2>> ${log}

echo -e "# archive ${pfx}.tgz and md5sum ${pfx}.tgz_md5.txt were created in ${1}" | tee -a ${log}

# fix file path in md5sum
sed -i "s|-|${4}.tgz|g" ${4}.tgz_md5.txt 2>> ${log}

echo -e "\n# Checking md5sum" 2>> ${log}

md5sum -c ${4}.tgz_md5.txt | tee -a ${4}.tgz_md5-check.txt 2>> ${log}
