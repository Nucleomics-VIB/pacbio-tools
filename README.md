[(Nucleomics-VIB)](https://github.com/Nucleomics-VIB)
![pacbio-tools](pictures/pacbio_icon.png) - PacBio-Tools
==========

*All tools presented below have only been tested by me and may contain bugs, please let me know if you find some. Each tool relies on dependencies normally listed at the top of the code (cpan for perl and cran for R will help you add them)*

Please refer to the accompanying **[wiki](https://github.com/Nucleomics-VIB/pacbio-tools/wiki)** for examples and workflows.

### Table of Contents

**[smrtlink-tools](#smrtlink-tools)**

- **[bam_subset_smrt.sh](#bam_subset_smrtsh)** - **[explain-LocalContextFlags.html](#explain-localcontextflagshtml)** - **[rundata2tgz.sh](#rundata2tgzsh)** - 

- **[bam2sizedist.sh](#bam2sizedistsh)** - 

## smrtlink-tools
*[[back-to-top](#top)]*  

### **bam_subset_smrt.sh**
*[[smrtlink-tools](#smrtlink-tools)]*

The bash script **[bam_subset_smrt.sh](/smrtlink-tools/bam_subset_smrt.sh)** takes arandom subset from a BAM data and user defined %value. It uses a random seed for each extarction to unsure that several runs will not overlap tool much at read level.
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

The bash file **[rundata2tgz.sh](/smrtlink-tools/rundata2tgz.sh)** creates a tar-gz archive from a local folder generated after aSequel run on the storage share. It ignores accessory files preseznt after a manual transfer.
```bash
# Usage: rundata2tgz.sh
# script version 1.0, 2017_01_23
## input files
# [required: -i <run-folder> (containing the flow-cell folder)]
# [-f <flowcell name (default <1_A01> for a single-cell run)>]
# [-o <output folder (default to <$SMRT_DOWNLOADS>]
# [-h for this help]
```

**[bam-utils](#bam-utils)**

### **bam2sizedist.sh**
*[bam-utils](#bam-utils)*

The bash file **[bam2sizedist.sh](/bam_utils/bam2sizedist.sh)** .
```bash
```

*[[back-to-top](#top)]*  

<hr>

<h4>Please send comments and feedback to <a href="mailto:nucleomics.bioinformatics@vib.be">nucleomics.bioinformatics@vib.be</a></h4>

<hr>

![Creative Commons License](http://i.creativecommons.org/l/by-sa/3.0/88x31.png?raw=true)

This work is licensed under a [Creative Commons Attribution-ShareAlike 3.0 Unported License](http://creativecommons.org/licenses/by-sa/3.0/).
