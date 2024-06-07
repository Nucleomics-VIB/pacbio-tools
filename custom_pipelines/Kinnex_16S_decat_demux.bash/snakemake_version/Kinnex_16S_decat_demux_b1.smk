# Snakefile: Kinnex_16S_decat_demux.smk
# Snakemake workflow to run skera and lima on a Kinnex 16S RUN
# Stephane Plaisance - VIB-NC 2024-06-03 v1.0

# visit our Git: https://github.com/Nucleomics-VIB

configfile: "config.yaml"

# Define rule all to specify the final outputs
rule all:
    input:
        "BundleResults_ok",
        "Archive_ok"

# Define rules corresponding to the functions in the Bash script
rule CopyBarcodeFiles:
    output:
        flag_file = "{reference}/CopyBarcodeFiles_ok"
    shell:
        """
        mkdir -p {config[reference]}
        barcode_dir=$(find {config[SMRT_BUNDLES]} -type d -name "barcodes" 2>/dev/null | head -n 1)
        if [ -d "$barcode_dir" ]; then
            cp -r $barcode_dir/MAS_adapter_indexes {config[reference]}/
            cp -r $barcode_dir/MAS-Seq_Adapter_v2 {config[reference]}/
            cp -r $barcode_dir/Kinnex16S_384plex_primers {config[reference]}/
            touch {output.flag_file}
        else
            echo "SMRTLink barcode directory not found."
            exit 1
        """

rule CopyRunData:
    output:
        flag_file = "{inputs}/CopyRunData_ok"
    shell:
        """
        mkdir -p {config[inputs]}
        if [ -d "{config[runfolder]}/{config[adapterfolder]}" ]; then
            cp -r "{config[runfolder]}/{config[adapterfolder]}" "{config[inputs]}/"
        else
            echo "Adapter folder not found: {config[runfolder]}/{config[adapterfolder]}"
            exit 1
        fi
        if [ -f "{config[runfolder]}/{config[samplesheet]}" ]; then
            cp "{config[runfolder]}/{config[samplesheet]}" "{config[inputs]}/"
        else
            echo "Sample sheet not found: {config[runfolder]}/{config[samplesheet]}"
            exit 1
        fi
        touch {output.flag_file}
        """

rule SkeraSplit:
    input:
        adapterfolder_ok = "{inputs}/CopyRunData_ok"
    output:
        flag_file = "{skera_results}/SkeraSplit_ok"
    shell:
        """
        mkdir -p {config[skera_results]}
        {config[SKERA_PATH]} split \
          {config[inputs]}/{config[adapterfolder]}/{config[movie]}.hifi_reads.{config[adapterfolder]}.bam \
          {config[reference]}/MAS-Seq_Adapter_v2/mas12_primers.fasta \
          {config[skera_results]}/{config[movie]}.skera.bam \
          --num-threads {config[nthr_skera]} \
          --log-level {config[log_skera]} \
          --log-file {config[skera_results]}/skera_run-log.txt
        touch {output.flag_file}
        """

rule Lima:
    input:
        skera_ok = "{skera_results}/SkeraSplit_ok"
    output:
        flag_file = "{lima_results}/Lima_ok"
    shell:
        """
        mkdir -p {config[lima_results]}
        {config[LIMA_PATH]} \
          {config[skera_results]}/{config[movie]}.skera.bam \
          {config[reference]}/Kinnex16S_384plex_primers/Kinnex16S_384plex_primers.fasta \
          {config[lima_results]}/HiFi.bam \
          --hifi-preset ASYMMETRIC \
          --split-named \
          --biosample-csv {config[inputs]}/{config[samplesheet]} \
          --split-subdirs \
          --num-threads {config[nthr_lima]} \
          --log-level {config[log_lima]} \
          --log-file {config[lima_results]}/lima_run-log.txt
        touch {output.flag_file}
        """

rule bam2fastq:
    input:
        lima_ok = "{lima_results}/Lima_ok"
    output:
        flag_file = "{lima_results}/bam2fastq_ok"
    shell:
        """
        mkdir -p {config[fastq_results]}
        cat /dev/null > job.list
        for bam in $(find {config[lima_results]} -name "*.bam"); do
            pfx=$(basename ${bam%.bam})
            bcpair=${pfx#HiFi.}
            biosample=$(grep ${bcpair} {config[inputs]}/{config[samplesheet]} | dos2unix | cut -d, -f 2 | tr -d "\n")
            echo "{config[BAM2FASTQ_PATH]} \
                ${bam} \
                --output {config[fastq_results]}/${biosample} \
                --num-threads {config[nthr_bam2fastq]}" >> job.list
        done
        parallel -j {config[par_bam2fastq]} --joblog my_job_log.log < job.list && (rm job.list my_job_log.log)
        touch {output.flag_file}
        """

rule BundleResults:
    input:
        bam2fastq_ok = "{lima_results}/bam2fastq_ok"
    output:
        flag_file = "BundleResults_ok"
    shell:
        """
        mkdir -p {config[final_results]}/info
        cp {config[runfolder]}/*.pdf {config[final_results]}/
        cp {config[ZYMOCTRL]} {config[final_results]}/info/
        cp {config[README]} {config[final_results]}/
        cp {config[inputs]}/{config[samplesheet]} {config[final_results]}/
        cp {config[lima_results]}/HiFi.lima.* {config[final_results]}/
        mv {config[fastq_results]} {config[final_results]}/
        projectnum=$(echo {config[samplesheet]} | cut -d "_" -f 1 | tr -d "\n")
        {config[PLOT_SH]} -i {config[final_results]}/HiFi.lima.counts -m {config[mincnt]} -f {config[qc_format]} -p ${projectnum} -s {config[inputs]}/{config[samplesheet]}
        cp barcode_QC_Kinnex.{config[qc_format]} {config[final_results]}/
        touch {output.flag_file}
        """

rule createArchive:
    input:
        bundle_ok = "BundleResults_ok"
    output:
        flag_file = "Archive_ok"
    shell:
        """
        thr=8
        pfx="$(echo {config[samplesheet]} | cut -d '_' -f 1 | tr -d '\n')_archive"
        { tar cvf - "{config[final_results]}" | pigz -p ${thr} | tee >(md5sum > ${pfx}.tgz_md5.txt) > ${pfx}.tgz; } 2> ${pfx}_content.log
        sed -i "s|-|${pfx}.tgz|g" ${pfx}.tgz_md5.txt
        md5sum -c ${pfx}.tgz_md5.txt | tee -a ${pfx}.tgz_md5-check.txt
        if grep -q "OK" "${pfx}.tgz_md5-check.txt"; then
            touch {output.flag_file}
        else
            echo "Flag file not created. Verification failed."
        """
