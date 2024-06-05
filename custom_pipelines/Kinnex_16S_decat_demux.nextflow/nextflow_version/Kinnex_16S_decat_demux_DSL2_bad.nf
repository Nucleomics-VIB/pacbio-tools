nextflow.enable.dsl=2

nextflow.enable.dsl=2

// Define parameters directly without the 'params.' prefix
runfolder = "/data/Sequel_data/4767_KDePaepe_PacBio/240524.Sequel2e.FCA"
movie = "m64279e_240524_094336"
adapterfolder = "bcM0002--bcM0002"
samplesheet = "Exp4767_SMRTLink_Barcodefile.csv"
SMRT_BUNDLES = "/opt/pacbio/smrtlink/install/current/bundles"
reference = "reference"
inputs = "inputs"
skera_results = "skera_results"
lima_results = "lima_results"
fastq_results = "fastq_results"
log_skera = "INFO"
log_lima = "INFO"
nthr_skera = 64
nthr_lima = 64
par_bam2fastq = 8
nthr_bam2fastq_par = 8

workflow {

    checkAndCreateCondaEnv()
    
    // Define a channel to read the env_vars.txt file and set the paths as workflow variables
    env_vars_ch = Channel.fromPath('env_vars.txt').map { file ->
        def env_vars = [:]
        file.readLines().each { line ->
            def (key, value) = line.split('=')
            env_vars[key.trim()] = value.trim()
        }
        env_vars
    }
    
    CopyMASIndexes()
    CopyRunData()

    SkeraSplit(env_vars)
    Lima(env_vars)

    bam_files = Channel.fromPath("\${params.lima_results}/*.bam")
    bam2fastq(env_vars, bam_files)
}

process checkAndCreateCondaEnv {
    output:
    path 'env_vars.txt'

    script:
    """
    if conda env list | grep 'pbbioconda'; then
        echo "Conda environment 'pbbioconda' already exists."
        conda activate pbbioconda || exit 1
    else
        echo "Creating Conda environment 'pbbioconda'."
        conda create -n pbbioconda
        conda activate pbbioconda
        conda install -c bioconda pbskera lima pbtk pbmm2 || exit 1
    fi

    // Store the paths to a list for use outside of this process
    echo "SKERA_PATH=\$(which skera)" > env_vars.txt
    echo "LIMA_PATH=\$(which lima)" >> env_vars.txt
    echo "BAM2FASTQ_PATH=\$(which bam2fastq)" >> env_vars.txt
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
    input:
    val env_vars
    
    script:
    """
    mkdir -p \${params.skera_results}
    \${env_vars['SKERA_PATH']} split \
      \${params.inputs}/\${params.adapterfolder}/\${params.movie}.hifi_reads.\${params.adapterfolder}.bam \
      \${params.reference}/MAS-Seq_Adapter_v2/mas12_primers.fasta \
      \${params.skera_results}/\${params.movie}.skera.bam \
      --num-threads \${params.nthr_skera} \
      --log-level \${params.log_skera} \
      --log-file \${params.skera_results}/skera_run-log.txt
    """
}

process Lima {
    input:
    val env_vars
    
    script:
    """
    mkdir -p \${params.lima_results}
    \${env_vars['LIMA_PATH']} \
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
    val env_vars
    
    script:
    """
    mkdir -p \${params.fastq_results}
    pfx=\${bam_file.baseName}
    bcpair=\${pfx.replaceFirst(/^HiFi\\./, '')}
    biosample=\$(grep \${bcpair} \${params.samplesheet} | tr -d '\\r' | cut -d, -f 2 | tr -d "\\n")
    nthr=\${params.nthr_bam2fastq}

    \${env_vars['BAM2FASTQ_PATH']} \
        \${bam_file} \
        --output \${params.fastq_results}/\${biosample} \
        --num-threads \${nthr}
    """
}
