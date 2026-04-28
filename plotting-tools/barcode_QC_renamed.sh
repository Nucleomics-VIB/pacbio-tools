#!/bin/bash
# usage: barcode_QC_renamed.sh -i <runid.hifi_reads.lima_counts.txt> -s <samplesheet.csv> -p <project#>
# optional: -f <pdf|html (default pdf)>
#           -F convert BAM to fastq (renamed by BioSample)
#           -B copy BAM to new folder (renamed by BioSample)
#
# plot mosaic from barcode CCS results and optionally rename BAM/FASTQ by BioSample name
# Samplesheet CSV maps full barcodes (bc2075--bc2075) to Bio Sample names
#
# Stephane Plaisance - VIB-Nucleomics Core
# 1.0, 2026_04_28

version="1.0, 2026_04_28"

# Rmd lives next to this script
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rmd_path="${script_dir}/barcode_QC_renamed.Rmd"

usage='# Usage: barcode_QC_renamed.sh
# -i <runid>.hifi_reads.lima_counts.txt file from SMRTlink (in statistics/)
# -s samplesheet CSV with Barcode,Bio Sample columns
# -p <opt: NC project code or title>
# -f <opt: output format pdf or HTML (default pdf)>
# -F <opt: convert BAM to fastq with BioSample names (default OFF)>
# -j <opt: bam2fastq internal threads (default 4)>
# -P <opt: number of BAM files processed in parallel (default 8)>
# -B <opt: copy BAM to new folder with BioSample names (default OFF)>
# -h <this help text>
# script version '${version}

while getopts "i:s:p:f:j:P:FBh" opt; do
  case $opt in
    i) opt_infile=${OPTARG} ;;
    s) opt_samplesheet=${OPTARG} ;;
    p) opt_project=${OPTARG} ;;
    f) opt_format=${OPTARG} ;;
    j) opt_threads=${OPTARG} ;;
    P) opt_parallel=${OPTARG} ;;
    F) convertbam=true ;;
    B) copybam=true ;;
    h) echo "${usage}" >&2; exit 0 ;;
    \?) echo "Invalid option: -${OPTARG}" >&2; exit 1 ;;
    *) echo "this command requires arguments, try -h" >&2; exit 1 ;;
  esac
done

#############################
# validate -i
if [ -z "${opt_infile}" ]; then
   echo
   echo "# no lima_counts.txt file provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_infile}" ]; then
   echo
   echo "# ${opt_infile} file not found!"
   exit 1
fi

# validate -s
if [ -z "${opt_samplesheet}" ]; then
   echo
   echo "# no samplesheet CSV provided!"
   echo "${usage}"
   exit 1
fi

if [ ! -f "${opt_samplesheet}" ]; then
   echo
   echo "# ${opt_samplesheet} file not found!"
   exit 1
fi

# validate -p
if [ -z "${opt_project}" ]; then
   echo
   echo "# no project code or title provided!"
   echo "${usage}"
   exit 1
fi

#############################
# parse samplesheet: Barcode,Bio Sample
# symmetric barcodes (bc2075--bc2075) -> short form bc2075
declare -A barcode_map
while IFS=, read -r barcode biosample; do
    [[ "$barcode" == "Barcode" ]] && continue
    # trim any trailing whitespace/CR from biosample (Windows line endings)
    biosample="${biosample%%$'\r'}"
    biosample="${biosample%% }"
    short_bc="${barcode%%--*}"
    barcode_map["$short_bc"]="$biosample"
done < "${opt_samplesheet}"

echo "# Loaded ${#barcode_map[@]} barcode→BioSample mappings from ${opt_samplesheet}"

# derive BAM file prefix from lima_counts.txt filename
# e.g. statistics/m84247_260424_120442_s1.hifi_reads.lima_counts.txt
# → m84247_260424_120442_s1.hifi_reads
bam_prefix=$(basename "${opt_infile}" .lima_counts.txt)
echo "# run prefix: ${bam_prefix}"
echo "# BAM pattern: hifi_reads/${bam_prefix}.<barcode>.bam (unassigned excluded)"

#############################
# output format (normalise to lowercase)
format="${opt_format:-pdf}"
format="${format,,}"

if [[ ${format} == "pdf" ]]; then
  outformat="pdf_document"
else
  outformat="html_document"
fi

#############################
# render Rmd report
cmd="R --slave -e 'rmarkdown::render(
  input=\"${rmd_path}\",
  output_format=\"${outformat}\",
  output_file=\"HiFi_barcode_QC.${format}\",
  output_dir=\"$PWD\",
  params=list(expRef=\"${opt_project}\",inputFile=\"$PWD/${opt_infile}\",sampleSheet=\"$PWD/${opt_samplesheet}\")
  )'"

echo "# ${cmd}"
eval "${cmd}"

#############################
# convert BAM to FASTQ with BioSample names
if [[ $convertbam == "true" ]]; then
  mkdir -p fastq_results
  bam_threads=${opt_threads:-4}
  bam_parallel=${opt_parallel:-8}
  bamcnt=${#barcode_map[@]}
  echo "# Converting ${bamcnt} BAM files to FASTQ (${bam_parallel} parallel jobs, ${bam_threads} threads each)"

  # build bam_file:::biosample pairs for parallel
  pairs=()
  for short_bc in "${!barcode_map[@]}"; do
    [[ "$short_bc" == "unassigned" ]] && continue
    biosample="${barcode_map[$short_bc]}"
    bam_file="hifi_reads/${bam_prefix}.${short_bc}.bam"
    if [[ -f "$bam_file" ]]; then
      pairs+=("${bam_file}:::${biosample}")
    else
      echo "# WARNING: BAM not found for barcode ${short_bc} (${biosample})"
    fi
  done

  printf '%s\n' "${pairs[@]}" | \
    parallel --colsep ':::' -j "${bam_parallel}" \
      "echo '# {1} -> fastq_results/{2}.fastq.gz' && bam2fastq -j ${bam_threads} -o fastq_results/{2} {1}"

  touch "bam2fastq_done.flag"

  fastqcnt=$(find fastq_results -type f -name "*.fastq.gz" | wc -l)
  echo "# ${fastqcnt} FASTQ files written to fastq_results/"

  if [[ ${fastqcnt} -ne ${bamcnt} ]]; then
    echo "# WARNING: FASTQ count (${fastqcnt}) does not match expected (${bamcnt})"
    exit 1
  fi
fi

#############################
# copy BAM files with BioSample names
if [[ $copybam == "true" ]]; then
  mkdir -p bam_results
  bamcnt=${#barcode_map[@]}
  echo "# Copying ${bamcnt} BAM files to bam_results/ (renamed by BioSample)"

  for short_bc in "${!barcode_map[@]}"; do
    [[ "$short_bc" == "unassigned" ]] && continue
    biosample="${barcode_map[$short_bc]}"
    bam_file="hifi_reads/${bam_prefix}.${short_bc}.bam"
    if [[ -f "$bam_file" ]]; then
      cp "$bam_file" "bam_results/${biosample}.bam"
      [[ -f "${bam_file}.pbi" ]] && cp "${bam_file}.pbi" "bam_results/${biosample}.bam.pbi"
    else
      echo "# WARNING: BAM not found for barcode ${short_bc} (${biosample})"
    fi
  done

  bamcnt2=$(find bam_results -type f -name "*.bam" | wc -l)
  echo "# ${bamcnt2} BAM files copied to bam_results/"

  if [[ ${bamcnt2} -ne ${bamcnt} ]]; then
    echo "# WARNING: copied BAM count (${bamcnt2}) does not match expected (${bamcnt})"
    exit 1
  fi
fi

#############################
# assemble runQC folder and create archive
transfer_dir="${opt_project}__Revio"
echo "# Assembling runQC folder"
mkdir -p runQC

cp "${opt_samplesheet}" runQC/
cp "${opt_infile}" runQC/

lima_summary="${opt_infile/lima_counts.txt/lima_summary.txt}"
if [[ -f "${lima_summary}" ]]; then
  cp "${lima_summary}" runQC/
else
  echo "# WARNING: ${lima_summary} not found, skipping"
fi

run_id="${bam_prefix%.hifi_reads}"
report_pdf="statistics/${run_id}.report.pdf"
if [[ -f "${report_pdf}" ]]; then
  cp "${report_pdf}" runQC/
else
  echo "# WARNING: ${report_pdf} not found, skipping"
fi

qc_report="HiFi_barcode_QC.${format}"
if [[ -f "${qc_report}" ]]; then
  cp "${qc_report}" runQC/
else
  echo "# WARNING: ${qc_report} not found, skipping"
fi

# build archive contents list
tar_items=("runQC/")
if [[ -d "fastq_results" ]]; then
  tar_items+=("fastq_results/")
else
  echo "# WARNING: fastq_results/ not found, not included in archive"
fi

archive_name="${bam_prefix}.results.tar.gz"
contents_file="${bam_prefix}.results.contents.txt"
echo "# Creating archive: ${archive_name}"
tar -czf "${archive_name}" "${tar_items[@]}"
tar -tzf "${archive_name}" > "${contents_file}"
echo "# Archive contents written to: ${contents_file}"

# md5 checksum (portable: md5sum on Linux, md5 on macOS)
if command -v md5sum &>/dev/null; then
  md5sum "${archive_name}" > "${archive_name}.md5"
else
  md5 -r "${archive_name}" > "${archive_name}.md5"
fi
echo "# MD5: $(cat "${archive_name}.md5")"

# assemble transfer folder
echo "# Assembling transfer folder: ${transfer_dir}"
mkdir -p "${transfer_dir}"
mv "${archive_name}" "${archive_name}.md5" "${contents_file}" "${transfer_dir}/"

cat > "${transfer_dir}/README.txt" << 'EOF'
-------------------------------------------------------------------------
README.txt
-------------------------------------------------------------------------

Data provided by the VIB Nucleomics core (nucleomics@vib.be).

DOWNLOAD USING CURL COMMAND LINE

The shared link would be like this https://nextnuc.gbiomed.kuleuven.be/index.php/s/XZYXZYXZY
where you could identify the token (e.g. XZYXZYXZY), and you should have received a password (e.g. we call it here l_connect_pwd).

        token=XZYXZYXZY
        l_connect_pwd=XXXX

You need also to specify which file you want to download. Usually the data are in archive format (e.g. archive.tgz).
        FILENAME="archive.tgz"

curl -C - -u "${token}:${l_connect_pwd}"  -o "${FILENAME}" "https://nextnuc.gbiomed.kuleuven.be/public.php/webdav/${FILENAME}"

DOWNLOAD USING WRAPPER SCRIPT

You can use the tool developed by Gert Huselmans (Stein Aerts Lab).
The tool only requires the link and password.
Then it lists the content of the share and allows you to select which files you want to download.
https://github.com/aertslab/nextcloud_share_url_downloader

CHECK TRANSFER

If you want to check whether you downloaded the large .tar file correctly, you can use the MD5-checksum (see file ending with md5sum.txt).
The checksum can be obtained with software such as http://winmd5.com.

UNPACK TAR ARCHIVE

To extract the tar archive file on a Linux/MacOSX system, you can use use the command 'tar -xzvf file.tar'
To extract the tar archive file on a Windows system, you can use 7zip (www.7-zip.org/).

------
Keep in mind that we will store your data on our servers only up to three months (starting from the delivery date).
If you have any questions, please contact us.

The VIB Nucleomics BioIT team.
EOF

cat > "${transfer_dir}/sharing_info.txt" << 'EOF'
share-URL: https://nextnuc.gbiomed.kuleuven.be/index.php/s/xxxxxxxxxxxxxxx
password: xxxxxxxxxx
(shared until 20YY-MM-DD)
EOF

echo "# Transfer folder ready: ${transfer_dir}/"

exit 0
