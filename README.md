[(Nucleomics-VIB)](https://github.com/Nucleomics-VIB)
![pacbio-tools](pictures/pacbio_icon.png) - PacBio-Tools
==========

*All tools presented below have only been tested by me and may contain bugs, please let me know if you find some. Each tool relies on dependencies normally listed at the top of the code (cpan for perl and cran for R will help you add them)*

Please refer to the accompanying **[wiki](https://github.com/Nucleomics-VIB/pacbio-tools/wiki)** for examples and workflows.

### Table of Contents

**[[smrtlink-tools](#smrtlink-tools)]**

- **[bam_subset_smrt.sh](#bam_subset_smrtsh)** - **[explain-LocalContextFlags.html](#explain-localcontextflagshtml)** - **[rundata2tgz.sh](#rundata2tgzsh)** - **[jobdata2tgz.sh](#jobdata2tgzsh)** - **[smrtlink_init.sh](#smrtlink_initsh)** - **[pbvcf2vcf4.pl](#pbvcf2vcf4pl)** -

**[[bam-utils](#bam-utils)]**

- **[pb2polymerase.sh](#pb2polymerasesh)** - **[SEQUELstats4one.sh](#sequelstats4onesh)** - **[sequel_read_lengths.R](#sequel_read_lengthsr)**  - **[bam_size-filter.pl](#bam_size-filterpl)** - **[bam2sizedist.sh](#bam2sizedistsh)** -

**[[general-tools](#general-tools)]**

- **[arrow_polish_asm.sh](#arrow_polish_asmsh)** - **[pb_STARlong.sh](#pb_starlongsh)** - 


## smrtlink-tools
*[[back-to-top](#top)]*  

### **bam_subset_smrt.sh**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash file **[bam_subset_smrt.sh](/smrtlink-tools/bam_subset_smrt.sh)** creates a  random subset from a BAM data and uploads the resulting file to the SMRT server as a new dataset.
```bash
# Usage: bam_subset_smrt.sh -b <input.bam>
# script version 1.0, 2017_01_18
# [optional: -o <output_prefix|sample_SS_XXpc>]
# [optional: -s <seed|1>]
# [optional: -f <fraction in %|10>]
# [optional: -t <threads|32>]
# [optional: -S <SMRT-server|"${smrthostname}">]
# [optional: -p <SMRT-port|9091>]
# [-h for this help]
```

### **explain-LocalContextFlags.html**
*[[smrtlink-tools](#smrtlink-tools)]*

The html file **[explain-LocalContextFlags.html](/smrtlink-tools/bam_subset_smrt.sh)** explains explain **LocalContext Flags** present in PacBio BAM data as a binary value in plain english. The content of this page is fully taken and adapted from a similar page dedicated to explaining SAM flags and hosted **<a href="http://picard.sourceforge.net/explain-flags.html">here</a>**. Please cite the PICARD source and not our version when using this code.
```bash
Open a local copy of the file using your favorite web browser to use it
```

### **rundata2tgz.sh**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash file **[rundata2tgz.sh](/smrtlink-tools/rundata2tgz.sh)** creates a tar-gz archive from a local folder generated after a Sequel run on the storage share. The script creates a md5sum file and verifies that the checksum is valid. This script should be ran for each subfolder present in a run folder (eg: 1_A01, 2_B01, ...).
```bash
# Usage: rundata2tgz.sh
# script version 1.1.1, 2017_09_20
## input files
# [required: -i <run-folder> (name of the run folder containing the flow-cell folder)]
# [-f <flowcell name (default <1_A01> for a single-cell run)>]
# [-o <output folder (default to <$GCDADA>]
# [-l <show the list of runs currently present on the server>]
# [-h for this help]
```

### **jobdata2tgz.sh**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash file **[jobdata2tgz.sh](/smrtlink-tools/jobdata2tgz.sh)** creates a tar-gz archive from a job folder generated after a SMRTLink run on the storage share. The script creates a md5sum file and verifies that the checksum is valid (rem: .las files are excluded from the archive)
```bash
# Usage: jobdata2tgz.sh
# script version 1.0, 2018_04_13
## input files
# [required: -i <job-folder> (name of the run folder containing the SMRTLink job)]
# [-o <output folder ($NCDATA|$GCDATA; default to <$GCDADA>)]
# [-S <JOB data root (default to <$SMRT_DATA/000>)]
# [-l <show the list of jobs currently present on the server>]
# [-h for this help]
```

### **smrtlink_init.sh**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash file **[smrtlink_init.sh](/smrtlink-tools/smrtlink_init.sh)** creates a launcher for the SMRT Link service (not tested).
```bash
# please use at your own risks
# info on how to set this can be found on the web
```

### **pbvcf2vcf4.pl**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash file **[pbvcf2vcf4.pl](/smrtlink-tools/pbvcf2vcf4.pl)** creates a VCF version 4.x copy of the SMRT vcf 3.3 file. The original format does not comply to VCF standards and the original GFF output does not help. The code requires the reference assembly file and its faidx index to add contig lines to the output and extract sequence at INS positions. The current code does only support haploid calls. This code is experimental and not finished.
```bash
# !!! this code is currently only valid for haploid calls
usage: pbvcf2vcf4.pl <pacbio_vcf3.3.vcf> <indexed-fasta-reference>
```

## bam-utils
*[[back-to-top](#top)]*  

### **pb2polymerase.sh**
*[[bam-utils](#bam-utils)]*

The shell wrapper **[pb2polymerase.sh](bam-utils/pb2polymerase.sh)** recreates polymerase reads from scraps and subreads using Pacbio **bam2bam**. Also reports polymerase lengths to be used in R for plotting.
```bash
Usage: pb2polymerase.sh <name>.scraps.bam> <threads|8>
```

### **SEQUELstats4one.sh**
*[[bam-utils](#bam-utils)]*

The shell wrapper **[SEQUELstats4one.sh](bam-utils/SEQUELstats4one.sh)** applies code fro mthe Welcome Sanger repo to a single smartcell dataset (thereby avoiding issues where bsub is not installed; read: https://github.com/VertebrateResequencing/SEQUELstats/issues/1)
```bash
Usage: SEQUELstats4one.sh <path to the Sequel BAM data>
```

### **sequel_read_lengths.R**
*[[bam-utils](#bam-utils)]*

The R script **[sequel_read_lengths.R](bam-utils/sequel_read_lengths.R)** reports subread and scrap read length distribution from a Sequel smartcell folder. It also plots polymerase lengths when they have been pre-processed using pb2polymerase.sh
```bash
Usage: sequel_read_lengths.R <path to the Sequel run data>
```

## **bam_size-filter.pl**
*[[bam-utils](#bam-utils)]*

The perl script **[bam_size-filter.pl](bam-utils/bam_size-filter.pl)** filters BAM records exports and saves length information (and optionally BAM data) to file(s).
```bash
Aim: Filter a BAM file by read length
#  print filtered read lengths to file
#  (also output kept reads to BAM if -b is set)
## Usage: bam_size-filter.pl <-i bam-file>
# optional <-m minsize>
# optional <-x maxsize>
# optional <-b to also create a BAM output (default only text file of lengths)>
# <-h to display this help>
```

### **bam2sizedist.sh**
*[[bam-utils](#bam-utils)]*

The bash file **[bam2sizedist.sh](/bam-utils/bam2sizedist.sh)** extracts from a BAM file: molecule ID, read length, barcode information, and polymerase coordinates, and saves results to a text table (TSV) for stats in R.
```bash
# provide a bam file to be parsed!
```

### **bam_size-filter.sh**
*[[bam-utils](#bam-utils)]*

The perl file **[bam_size-filter.pl](/bam-utils/bam_size-filter.pl)** filters BAM records by min and max length. It output all filtered lengths to file for stats and can also create a BAM output (optional).
```bash
Aim: Filter a BAM file by read length
#  print filtered read lengths to# please provide mandatory arguments -q and -d!
# Usage: pb_STARlong.sh 
# -q <query sequences (reads)> 
# -d <STAR_database-folder>
# optional -t <threads> (default 8)>
# script version 1.0, 2017_03_03
# [-h for this help] file
#  (also output kept reads to BAM if -b is set)
## Usage: bam_size-filter.pl <-i bam-file>
# optional <-m minsize>
# optional <-x maxsize>
# optional <-b to also create a BAM output (default only text file of lengths)>
# <-h to display this help>
```

## general-tools
*[[back-to-top](#top)]*  

### **arrow_polish_asm.sh**
*[[general-tools](#general-tools)]*

The facilitating bash script **[arrow_polish_asm.sh](general-tools/arrow_polish_asm.sh)** maps Sequel reads to a draft Fasta assembly and uses the mapped reads to correct basecall errors and produce a polished version of the assembly.
```bash
# Usage: arrow_polish_asm.sh -a <fasta assembly> -b <sequel reads (bam)> 
# [optional: -p <smrt_bin path> (suggested: /opt/pacbio/smrtlink/smrtcmds/bin)
# [optional: -o <result folder>]
# [optional: -t <available threads|1>]
# [optional: -h <this help text>]
# script version 1.0, 2017_12_13
```

### **pb_STARlong.sh**
*[[general-tools](#general-tools)]*

The facilitating bash script **[pb_STARlong.sh](general-tools/pb_STARlong.sh)** runs a preconfigured STARlong command with PacBio reads (Fasta). The arguments used in this script were reproduced from the dedicated Github page https://github.com/PacificBiosciences/cDNA_primer/wiki/Bioinfx-study:-Optimizing-STAR-aligner-for-Iso-Seq-data and can be amended when changes are necessary.
```bash
# Usage: pb_STARlong.sh 
# -q <query sequences (reads)> 
# -d <STAR_database-folder>
# optional -t <threads> (default 8)>
# script version 1.0, 2017_03_03
# [-h for this help]
```

*[[back-to-top](#top)]*  

<hr>

<h4>Please send comments and feedback to <a href="mailto:nucleomics.bioinformatics@vib.be">nucleomics.bioinformatics@vib.be</a></h4>

<hr>

![Creative Commons License](http://i.creativecommons.org/l/by-sa/3.0/88x31.png?raw=true)

This work is licensed under a [Creative Commons Attribution-ShareAlike 3.0 Unported License](http://creativecommons.org/licenses/by-sa/3.0/).
