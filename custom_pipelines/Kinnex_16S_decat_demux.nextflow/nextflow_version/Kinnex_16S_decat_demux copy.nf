#!/usr/bin/env nextflow

##########################################
# to be edited by the user before running
##########################################
params.runfolder = "/data/Sequel_data/4767_KDePaepe_PacBio/240524.Sequel2e.FCA"
params.movie = "m64279e_240524_094336"
params.adapterfolder = "bcM0002--bcM0002"

# the samplesheet should be present in the run folder
params.samplesheet = "Exp4767_SMRTLink_Barcodefile.csv"


##################
# global defaults
##################

# SMRTLink should be installed on the local machine to provide the executables
params.SMRT_BUNDLES = "/opt/pacbio/smrtlink/install/current/bundles"

# output folders
params.reference = "reference"
params.inputs = "inputs"
params.skera_results = "skera_results"
params.lima_results = "lima_results"
params.fastq_results = "fastq_results"

# log level
params.log_skera = "INFO"
params.log_lima = "INFO"

# threads adapted to local resurces
params.nthr_skera = 64
params.nthr_lima = 64
params.par_bam2fastq = 8
params.nthr_bam2fastq_par = 8

###########
# PIPELINE
###########

process checkAndCreateCondaEnv {
    output:
    env(SKERA_PATH: '', LIMA_PATH: '', BAM2FASTQ_PATH: '')

    script:
    """
    if conda env list | grep 'pbbioconda'; then
        echo "Conda environment 'pbbioconda' already exists."
        source activate pbbioconda || exit 1
    else
        echo "Creating Conda environment 'pbbioconda'."
        conda create -n pbbioconda
        source activate pbbioconda
        conda install -c bioconda pbskera lima pbtk pbmm2 || exit 1
    fi

    # create local paths for use outside of this conda env
    # create path to skera
    export SKERA_PATH=\$(which skera)
    if [[ -z "\$SKERA_PATH" ]]; then
        echo "Error: skera executable not found in the 'pbbioconda' environment."
        exit 1
    fi

    # create path to lima
    export LIMA_PATH=\$(which lima)
    if [[ -z "\$LIMA_PATH" ]]; then
        echo "Error: lima executable not found in the 'pbbioconda' environment."
        exit 1
    fi

    # create path to bam2fastq
    export BAM2FASTQ_PATH=\$(which bam2fastq)
    if [[ -z "\$BAM2FASTQ_PATH" ]]; then
        echo "Error: bam2fastq executable not found in the 'pbbioconda' environment."
        exit 1
    fi

    # exit env and return to nextflow env
    conda deactivate
    """
}

process CopyMASIndexes {
    script:
    """
    mkdir -p \${params.reference}
    cp -r \${params.SMRT_BUNDLES}/smrtinub/install/smrtinub-release_*/private/pacbio/barcodes/MAS* \${params.reference}/
    cp -r \${params.SMRT_BUNDLES}/smrtinub/install/smrtinub-release_*/private/pacbio/barcodes/Kinnex16S_384plex_primers \${params.reference}/
    """
}

process CopyRunData {
    script:
    """
    mkdir -p \${params.inputs}
    cp -r \${params.runfolder}/\${params.adapterfolder} \${params.inputs}/
    cp \${params.runfolder}/\${params.samplesheet} \${params.inputs}/
    """
}

process SkeraSplit {
    script:
    """
    mkdir -p \${params.skera_results}
    \$SKERA_PATH split \
      \${params.inputs}/\${params.adapter}/\${params.movie}.hifi_reads.\${params.adapter}.bam \
      \${params.reference}/MAS-Seq_Adapter_v2/mas12_primers.fasta \
      \${params.skera_results}/\${params.movie}.skera.bam \
      --num-threads \${params.nthr_skera} \
      --log-level \${params.log_skera} \
      --log-file \${params.skera_results}/skera_run-log.txt
    """
}

process Lima {
    script:
    """
    mkdir -p \${params.lima_results}
    \$LIMA_PATH \
      \${params.skera_results}/\${params.movie}.skera.bam \
      \${params.reference}/Kinnex16S_384plex_primers/Kinnex16S_384plex_primers.fasta \
      \${params.lima_results}/HiFi.bam \
      --hifi-preset ASYMMETRIC \
      --split-named \
      --biosample-csv \${params.inputs}/\${params.samplesheet} \
      --split-subdirs \
      --num-threads \${params.nthr_lima} \
      --log-level \${params.log_lima} \
      --log-file \${params.lima_results}/lima_run-log.txt
    """
}

Channel
    .fromPath("\${params.lima_results}/*.bam")
    .set { bam_files }

process bam2fastq {
    cpus \${params.nthr_bam2fastq_par}

    input:
    path bam_file from bam_files.collect().map { it -> it.toList().collate(\${params.par_bam2fastq}) }.flatten()

    script:
    """
    mkdir -p \${params.fastq_results}
    pfx=\${bam_file.baseName}
    bcpair=\${pfx.replaceFirst(/^HiFi\\./, '')}
    biosample=\$(grep \${bcpair} \${params.samplesheet} | tr -d '\\r' | cut -d, -f 2 | tr -d "\\n")
    nthr=\${params.nthr_bam2fastq}

    \$BAM2FASTQ_PATH \
        ${bam} \
        --output \${params.fastq_results}/\${biosample} \
        --num-threads ${task.cpus}
    """
}
    
# process bam2fastq_ori {
#     script:
#     """
#     mkdir -p \${params.fastq_results}
#     cat /etc/null > job.list
#     
#     # prepare job list from a loop
#     for bam in $(find \${params.lima_results} -name "*.bam"); do
#         pfx=$(basename ${bam%.bam})
#         bcpair=${pfx#HiFi.}
#         biosample=$(grep ${bcpair} ${samplesheet} | dos2unix | cut -d, -f 2 | tr -d "\n")
#         nthr=\${params.nthr_bam2fastq}
# 
#         echo "bam2fastq \
#             ${bam} \
#             --output \${params.fastq_results}/${biosample} \
#             --num-threads ${nthr}" >> job.list
#     done
# 
#     # execute job list in batches of \${params.nthr_bam2fastq_par}
#     parallel -j \${params.nthr_bam2fastq_par} --joblog my_job_log.log < job.list && (rm job.list my_job_log.log)
#     """
# }

