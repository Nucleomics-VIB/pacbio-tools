#!/bin/bash

# install_deps.sh
# Script to download and extract all dependencies for hifiBam2metrics
# Run this script after cloning the repository to prepare the build environment

set -e  # Exit on any error

echo "=== hifiBam2metrics Dependency Installer ==="
echo "This script will download and extract all required libraries"
echo

# Function to download and extract a file
download_and_extract() {
    local url="$1"
    local filename="$2"
    local extract_cmd="$3"
    
    echo "Downloading $filename..."
    if [ ! -f "$filename" ]; then
        wget -q --show-progress "$url" -O "$filename"
        echo "✓ Downloaded $filename"
    else
        echo "✓ $filename already exists, skipping download"
    fi
    
    echo "Extracting $filename..."
    eval "$extract_cmd"
    echo "✓ Extracted $filename"
    echo
}

# Check if wget is available
if ! command -v wget &> /dev/null; then
    echo "Error: wget is required but not installed."
    echo "Please install wget first:"
    echo "  Ubuntu/Debian: sudo apt-get install wget"
    echo "  CentOS/RHEL:   sudo yum install wget"
    echo "  macOS:         brew install wget"
    exit 1
fi

echo "Starting dependency downloads..."
echo

# Download htslib (HTSlib - C library for high-throughput sequencing data formats)
download_and_extract \
    "https://github.com/samtools/htslib/releases/download/1.20/htslib-1.20.tar.bz2" \
    "htslib-1.20.tar.bz2" \
    "tar -xjf htslib-1.20.tar.bz2"

# Download zlib (compression library)
download_and_extract \
    "https://zlib.net/zlib-1.3.1.tar.gz" \
    "zlib-1.3.1.tar.gz" \
    "tar -xzf zlib-1.3.1.tar.gz"

# Download bzip2 (compression library)
download_and_extract \
    "https://sourceware.org/pub/bzip2/bzip2-1.0.8.tar.gz" \
    "bzip2-1.0.8.tar.gz" \
    "tar -xzf bzip2-1.0.8.tar.gz"

# Download xz/lzma (compression library)
download_and_extract \
    "https://github.com/tukaani-project/xz/releases/download/v5.4.4/xz-5.4.4.tar.gz" \
    "xz-5.4.4.tar.gz" \
    "tar -xzf xz-5.4.4.tar.gz"

# Download samtools (optional - for reference)
download_and_extract \
    "https://github.com/samtools/samtools/releases/download/1.20/samtools-1.20.tar.bz2" \
    "samtools-1.20.tar.bz2" \
    "tar -xjf samtools-1.20.tar.bz2"

echo "=== Dependency Installation Complete ==="
echo
echo "All dependencies have been downloaded and extracted successfully!"
echo "You can now build the project with:"
echo "  make"
echo
echo "Files downloaded:"
echo "  • htslib-1.20.tar.bz2 + extracted directory"
echo "  • zlib-1.3.1.tar.gz + extracted directory"
echo "  • bzip2-1.0.8.tar.gz + extracted directory"
echo "  • xz-5.4.4.tar.gz + extracted directory (LZMA support)"
echo "  • samtools-1.20.tar.bz2 + extracted directory (reference)"
echo
echo "Build dependencies ready!"
