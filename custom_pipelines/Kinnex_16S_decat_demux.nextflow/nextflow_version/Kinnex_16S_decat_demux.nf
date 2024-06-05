nextflow.enable.dsl=2

// User defined parameters
runfolder = "/data/Sequel_data/4767_KDePaepe_PacBio/240524.Sequel2e.FCA"
movie = "m64279e_240524_094336"
adapterfolder = "bcM0002--bcM0002"
samplesheet = "Exp4767_SMRTLink_Barcodefile.csv"

// paths to PacBio references and tools
SMRT_BUNDLES = "/opt/pacbio/smrtlink/install/current/bundles"

SKERA_PATH = "/opt/pacbio/smrtlink/smrtcmds/bin/skera"
LIMA_PATH = "/opt/pacbio/smrtlink/smrtcmds/bin/lima"
BAM2FASTQ_PATH = "/opt/pacbio/smrtlink/smrtcmds/bin/bam2fastq"

// Run parameters
reference = "reference"
inputs = "inputs"
skera_results = "skera_results"
lima_results = "lima_results"
fastq_results = "fastq_results"
log_skera = "INFO"
log_lima = "INFO"

// allocated resources
nthr_skera = 64
nthr_lima = 64
par_bam2fastq = 8
nthr_bam2fastq_par = 8

workflow {
    CopyMASIndexes()
    CopyRunData()

    SkeraSplit()
    Lima()

    bam_files = Channel.fromPath("\${params.lima_results}/*.bam")
    bam2fastq(bam_files)
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
    \${params.SKERA_PATH} split \
      \${params.inputs}/\${params.adapterfolder}/\${params.movie}.hifi_reads.\${params.adapterfolder}.bam \
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
    \${params.LIMA_PATH} \
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

process bam2fastq {
    cpus params.nthr_bam2fastq_par

    input:
    path bam_file
    
    script:
    """
    mkdir -p \${params.fastq_results}
    pfx=\${bam_file.baseName}
    bcpair=\${pfx.replaceFirst(/^HiFi\\./, '')}
    biosample=\$(grep \${bcpair} \${params.samplesheet} | tr -d '\\r' | cut -d, -f 2 | tr -d "\\n")
    nthr=\${params.nthr_bam2fastq}

    \${params.BAM2FASTQ_PATH} \
        \${bam_file} \
        --output \${params.fastq_results}/\${biosample} \
        --num-threads \${nthr}
    """
}
