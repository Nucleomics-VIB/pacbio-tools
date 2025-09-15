# hifiBam2metrics

Fast C implementation for extracting metrics from PacBio HiFi BAM files using htslib.

## Overview

This is a standalone, high-performance C program that extracts PacBio HiFi sequencing metrics from BAM files. It uses the htslib library for direct BAM file parsing, providing significant performance improvements over shell script implementations.

## Features

- **Fast**: Direct BAM parsing using htslib (no external samtools dependency)
- **Standalone**: All dependencies included as source code
- **Compatible**: Outputs same CSV format as shell script versions
- **Robust**: Proper error handling and memory management

## Output Metrics

The program extracts the following PacBio HiFi metrics:
- **readID**: Unique read identifier
- **length**: Read length in base pairs
- **np**: Number of passes (subreads used for consensus)
- **rq**: Read quality (accuracy estimate)
- **bq**: Barcode quality

## Library Download Commands (for reference)

The following commands were used to download and prepare the source libraries included in this project:

```bash
# Download htslib (HTSlib - C library for high-throughput sequencing data formats)
wget https://github.com/samtools/htslib/releases/download/1.20/htslib-1.20.tar.bz2
tar -xjf htslib-1.20.tar.bz2

# Download zlib (compression library)
wget https://zlib.net/zlib-1.3.1.tar.gz
tar -xzf zlib-1.3.1.tar.gz

# Download bzip2 (compression library)
wget https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz
tar -xzf bzip2-1.0.8.tar.gz

# Download xz/lzma (compression library for CRAM support)
wget https://github.com/tukaani-project/xz/releases/download/v5.4.4/xz-5.4.4.tar.gz
tar -xzf xz-5.4.4.tar.gz

# Optional: Download samtools (for reference, not needed for this project)
wget https://github.com/samtools/samtools/releases/download/1.20/samtools-1.20.tar.bz2
tar -xjf samtools-1.20.tar.bz2
```

## Building

### Prerequisites

Only basic build tools are required (no external libraries needed):
- GCC compiler
- Make
- wget (for downloading dependencies)
- POSIX-compliant system (Linux, macOS, WSL)

### Quick Start

```bash
# 1. Download and extract all dependencies
./install_deps.sh

# 2. Compile the program
make

# 3. Run on a BAM file
./hifiBam2metrics input.bam
```

### Manual Compilation

```bash
# If you prefer to download dependencies manually, use the commands in the 
# "Library Download Commands" section below, then:

# Compile the program
make

# Clean build files
make clean

# Force rebuild all dependencies
make clean-all
make
```

## Usage

```bash
# Run on a BAM file
./hifiBam2metrics input.bam

# Output will be created as: input_hifi_metrics.txt
```

## Output Format

The output is a tab-separated file with header:
```
readID	length	np	rq	bq
m84047_240101_123456_s1_p0/1/ccs	15234	25	0.9989	93
m84047_240101_123456_s1_p0/2/ccs	12456	18	0.9972	89
...
```

## Performance

This C implementation provides significant performance improvements over shell script alternatives:
- Direct BAM parsing (no subprocesses)
- Optimized memory usage
- Efficient htslib library functions
- Compiled with `-O3` optimization

## Dependencies Included

- **htslib 1.20**: Core BAM/SAM/CRAM processing library
- **zlib 1.3.1**: Compression library (required by htslib)
- **bzip2 1.0.8**: Compression library (required by htslib)
- **xz 5.4.4**: LZMA compression library (required for CRAM support)
- **samtools 1.20**: Reference implementation (not used in build)

## License

This project builds upon:
- htslib: MIT/Expat License
- zlib: zlib License
- bzip2: BSD-style License

All source libraries retain their original licenses.
