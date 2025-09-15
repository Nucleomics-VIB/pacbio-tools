# Makefile for hifiBam2metrics standalone project
# Fast C implementation for PacBio HiFi BAM metrics extraction with bundled dependencies

CC = gcc
CFLAGS = -O3 -Wall -Wextra -std=c99 -static
TARGET = hifiBam2metrics
SOURCE = hifiBam2metrics.c

# Local dependency paths
ZLIB_DIR = zlib-1.3.1
BZIP2_DIR = bzip2-1.0.8
XZ_DIR = xz-5.4.4
HTSLIB_DIR = htslib-1.20
SAMTOOLS_DIR = samtools-1.20

# Include paths for local libraries
INCLUDES = -I$(HTSLIB_DIR) -I$(ZLIB_DIR) -I$(BZIP2_DIR) -I$(XZ_DIR)/src/liblzma/api

# Use static libraries directly (no -L flags to avoid system library conflicts)
STATIC_LIBS = $(HTSLIB_DIR)/libhts.a $(ZLIB_DIR)/libz.a $(BZIP2_DIR)/libbz2.a $(XZ_DIR)/src/liblzma/.libs/liblzma.a
SYS_LIBS = -lpthread -lm -ldl

# Build all dependencies first, then the main target
all: deps $(TARGET)

# Build dependencies
deps: $(ZLIB_DIR)/libz.a $(BZIP2_DIR)/libbz2.a $(XZ_DIR)/src/liblzma/.libs/liblzma.a $(HTSLIB_DIR)/libhts.a

# Build zlib
$(ZLIB_DIR)/libz.a:
	cd $(ZLIB_DIR) && CFLAGS="-fPIC" ./configure --static && $(MAKE)

# Build bzip2
$(BZIP2_DIR)/libbz2.a:
	cd $(BZIP2_DIR) && $(MAKE) CFLAGS="-fPIC" libbz2.a

# Build xz/lzma
$(XZ_DIR)/src/liblzma/.libs/liblzma.a:
	cd $(XZ_DIR) && CFLAGS="-fPIC" ./configure --disable-shared --enable-static --disable-doc --disable-scripts --disable-xz --disable-xzdec --disable-lzmadec --disable-lzmainfo && $(MAKE)

# Build htslib (depends on zlib, bzip2, and lzma)
$(HTSLIB_DIR)/libhts.a: $(ZLIB_DIR)/libz.a $(BZIP2_DIR)/libbz2.a $(XZ_DIR)/src/liblzma/.libs/liblzma.a
	cd $(HTSLIB_DIR) && \
	PKG_CONFIG_PATH="../$(ZLIB_DIR):../$(BZIP2_DIR):../$(XZ_DIR)/src/liblzma" \
	CPPFLAGS="-I../$(ZLIB_DIR) -I../$(BZIP2_DIR) -I../$(XZ_DIR)/src/liblzma/api" \
	LDFLAGS="-L../$(ZLIB_DIR) -L../$(BZIP2_DIR) -L../$(XZ_DIR)/src/liblzma/.libs" \
	LIBS="-lz -lbz2 -llzma" \
	CFLAGS="-fPIC" \
	./configure --disable-libcurl --disable-gcs --disable-s3 --with-libdeflate=no \
		--enable-static --disable-shared \
		--with-zlib=../$(ZLIB_DIR) \
		--with-bz2=../$(BZIP2_DIR) \
		--with-lzma=../$(XZ_DIR) && \
	$(MAKE) libhts.a

# Main target
$(TARGET): $(SOURCE) deps
	$(CC) $(CFLAGS) $(INCLUDES) -o $(TARGET) $(SOURCE) $(STATIC_LIBS) $(SYS_LIBS)

# Clean compiled files and dependencies
clean:
	rm -f $(TARGET)

# Clean everything including built dependencies
clean-all:
	rm -f $(TARGET)
	cd $(ZLIB_DIR) && $(MAKE) clean || true
	cd $(BZIP2_DIR) && $(MAKE) clean || true
	cd $(XZ_DIR) && $(MAKE) clean || true
	cd $(HTSLIB_DIR) && $(MAKE) clean || true

# Install target (optional)
install: $(TARGET)
	cp $(TARGET) /usr/local/bin/

# Test with a sample BAM file (if available)
test: $(TARGET)
	@if [ -f test.bam ]; then \
		./$(TARGET) test.bam; \
	else \
		echo "No test.bam file found. Create one to test."; \
	fi

.PHONY: all deps clean clean-all install test

# Build requirements:
# - build-essential package for gcc (Ubuntu/Debian: sudo apt-get install build-essential)
# - No external libraries needed - all dependencies are bundled and statically linked!

# Usage:
# make all          # Build all dependencies and hifiBam2metrics (fully static)
# make clean        # Clean only the main target
# make clean-all    # Clean everything including dependencies
# ./hifiBam2metrics input.bam    # Run on BAM file (no library warnings!)
# Output: input_hifi_metrics.txt

# This is now a standalone project that can be moved anywhere and built without
# requiring system installation of samtools, htslib, zlib, or bzip2.
# The resulting binary is fully static and has no external library dependencies.
