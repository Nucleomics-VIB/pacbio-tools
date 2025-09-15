/*
 * hifiBam2metrics.c - Fast C implementation using htslib
 * 
 * Parse PacBio HiFi BAM files and extract metrics:
 * - readID, read length, pass number, read quality score, barcode quality score
 * 
 * Compilation:
 * gcc -O3 -o hifiBam2metrics hifiBam2metrics.c -lhts -lz -lpthread -lm
 * 
 * Usage:
 * ./hifiBam2metrics input.bam
 * 
 * Output: input_hifi_metrics.txt
 * 
 * Based on hifiBam2metrics_auto.sh
 * Stéphane Plaisance - VIB-NC 2025-09-10 v2.0
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <htslib/sam.h>
#include <htslib/hts.h>

// Extract integer value from aux tag
int get_aux_int(bam1_t *b, const char *tag) {
    uint8_t *aux = bam_aux_get(b, tag);
    if (!aux) return -1;
    return bam_aux2i(aux);
}

// Extract float value from aux tag
float get_aux_float(bam1_t *b, const char *tag) {
    uint8_t *aux = bam_aux_get(b, tag);
    if (!aux) return -1.0f;
    return bam_aux2f(aux);
}

// Extract molecule ID from read name (part after first '/')
void extract_molecule_id(const char *qname, char *mol_id, size_t max_len) {
    const char *slash = strchr(qname, '/');
    if (slash && strlen(slash) > 1) {
        slash++; // Skip the '/'
        const char *next_slash = strchr(slash, '/');
        if (next_slash) {
            size_t len = next_slash - slash;
            if (len < max_len) {
                strncpy(mol_id, slash, len);
                mol_id[len] = '\0';
                return;
            }
        }
    }
    strncpy(mol_id, "unknown", max_len - 1);
    mol_id[max_len - 1] = '\0';
}

// Generate output filename from input BAM filename
void generate_output_filename(const char *input_bam, char *output_file, size_t max_len) {
    const char *basename = strrchr(input_bam, '/');
    basename = basename ? basename + 1 : input_bam;
    
    // Find .bam extension and replace with _hifi_metrics.txt
    const char *ext = strstr(basename, ".bam");
    if (ext) {
        size_t prefix_len = ext - basename;
        snprintf(output_file, max_len, "%.*s_hifi_metrics.txt", (int)prefix_len, basename);
    } else {
        snprintf(output_file, max_len, "%s_hifi_metrics.txt", basename);
    }
}

int main(int argc, char *argv[]) {
    // Check for help flag or no arguments
    if (argc == 1 || (argc == 2 && (strcmp(argv[1], "-h") == 0 || strcmp(argv[1], "--help") == 0))) {
        fprintf(stderr, "Usage: %s <input.bam>\n", argv[0]);
        fprintf(stderr, "Extract PacBio HiFi metrics from BAM file\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "Output: Creates <input>_hifi_metrics.txt with read metrics\n");
        fprintf(stderr, "\n");
        fprintf(stderr, "For parallel processing of multiple BAM files:\n");
        fprintf(stderr, "  find . -name \"*.bam\" | parallel --tag --line-buffer -j 4 hifiBam2metrics {}\n");
        fprintf(stderr, "\n");
        return argc == 1 ? 1 : 0;
    }
    
    if (argc != 2) {
        fprintf(stderr, "Error: Expected exactly one BAM file argument\n");
        fprintf(stderr, "Usage: %s <input.bam>\n", argv[0]);
        fprintf(stderr, "Use -h for more information\n");
        return 1;
    }

    const char *bam_file = argv[1];
    char output_file[512];
    generate_output_filename(bam_file, output_file, sizeof(output_file));

    // Open BAM file
    samFile *in = sam_open(bam_file, "r");
    if (!in) {
        fprintf(stderr, "Error: Cannot open BAM file %s\n", bam_file);
        return 1;
    }

    // Read header
    sam_hdr_t *header = sam_hdr_read(in);
    if (!header) {
        fprintf(stderr, "Error: Cannot read BAM header\n");
        sam_close(in);
        return 1;
    }

    // Open output file
    FILE *out = fopen(output_file, "w");
    if (!out) {
        fprintf(stderr, "Error: Cannot create output file %s\n", output_file);
        sam_hdr_destroy(header);
        sam_close(in);
        return 1;
    }

    // Write header
    fprintf(out, "Mol.ID,len,npass,Accuracy,bcqual\n");

    // Process reads
    bam1_t *b = bam_init1();
    long total_reads = 0;
    long processed_reads = 0;

    fprintf(stderr, "Processing BAM file: %s\n", bam_file);
    fprintf(stderr, "Output file: %s\n", output_file);

    while (sam_read1(in, header, b) >= 0) {
        total_reads++;
        
        // Progress indicator
        if (total_reads % 100000 == 0) {
            fprintf(stderr, "Processed %ld reads...\n", total_reads);
        }

        // Skip secondary and supplementary alignments
        if (b->core.flag & (BAM_FSECONDARY | BAM_FSUPPLEMENTARY)) {
            continue;
        }

        // Extract read name and molecule ID
        char *qname = bam_get_qname(b);
        char mol_id[256];
        extract_molecule_id(qname, mol_id, sizeof(mol_id));

        // Extract read length (sequence length)
        int read_length = b->core.l_qseq;

        // Extract auxiliary tags
        int num_passes = get_aux_int(b, "np");
        float read_quality = get_aux_float(b, "rq");
        int barcode_quality = get_aux_int(b, "bq");

        // Skip reads missing essential tags
        if (num_passes < 0 || read_quality < 0) {
            continue;
        }

        // Handle missing barcode quality (set to 0 for non-barcoded data)
        if (barcode_quality < 0) {
            barcode_quality = 0;
        }

        // Clamp read quality to reasonable range (0.0 - 1.0)
        if (read_quality > 1.0f) read_quality = 1.0f;
        if (read_quality < 0.0f) read_quality = 0.0f;

        // Write metrics
        fprintf(out, "%s,%d,%d,%.6f,%d\n", 
                mol_id, read_length, num_passes, read_quality, barcode_quality);
        
        processed_reads++;
    }

    // Cleanup
    bam_destroy1(b);
    fclose(out);
    sam_hdr_destroy(header);
    sam_close(in);

    fprintf(stderr, "Completed: Processed %ld reads, extracted metrics for %ld reads\n", 
            total_reads, processed_reads);
    fprintf(stderr, "Output saved to: %s\n", output_file);

    return 0;
}
