#!/usr/bin/env Rscript

#' plot_lima_report.R - Lima Report Visualization Tool
#' 
#' @description
#' This script creates visualization plots from PacBio Lima demultiplexing reports.
#' It generates read length histograms and boxplots to assess demultiplexing quality.
#' 
#' @author SP (+Claude Sonnet 4) - VIB Nucleomics Core
#' @date October 13, 2025
#' @version 1.0.0
#' 
#' @usage
#' Rscript plot_lima_report.R [OPTIONS]
#' 
#' @examples
#' # Basic usage with default parameters
#' Rscript plot_lima_report.R -i HiFi.lima.report
#' 
#' # Custom size range
#' Rscript plot_lima_report.R -i HiFi.lima.report -m 800 -M 1800
#' 
#' @details
#' The script reads a Lima report TSV file and generates:
#' 1. size_histogram.png - Density plot of read lengths by filter status
#' 2. size_boxplot.png - Boxplot of read lengths by sample (passed filters only)
#' 
#' Output files are saved in the current working directory.

# Load required libraries
suppressPackageStartupMessages({
  library("optparse")
  library("readr")
  library("ggplot2")
  library("dplyr")
})

# Define command line options
option_list <- list(
  make_option(c("-i", "--input"), 
              type = "character", 
              default = "HiFi.lima.report",
              help = "Input Lima report file [default: %default]"),
  
  make_option(c("-m", "--min-size"), 
              type = "integer", 
              default = 1000,
              help = "Minimum read length for plots [default: %default]"),
  
  make_option(c("-M", "--max-size"), 
              type = "integer", 
              default = 1600,
              help = "Maximum read length for plots [default: %default]")
)

# Parse command line arguments
opt_parser <- OptionParser(option_list = option_list, 
                          prog = "plot_lima_report.R",
                          description = "\nVisualize PacBio Lima demultiplexing reports\n",
                          epilogue = "\nExample:\n  Rscript plot_lima_report.R -i HiFi.lima.report -m 800 -M 1600\n")

opt <- parse_args(opt_parser)

# Validate input file
if (!file.exists(opt$input)) {
  cat("Error: Input file '", opt$input, "' not found.\n", sep = "")
  quit(status = 1)
}

# Validate size parameters
if (opt$`min-size` >= opt$`max-size`) {
  cat("Error: min-size must be less than max-size.\n")
  quit(status = 1)
}

cat("Lima Report Visualization\n")
cat("=========================\n")
cat("Input file:", opt$input, "\n")
cat("Size range:", opt$`min-size`, "-", opt$`max-size`, "\n")
cat("Output directory:", getwd(), "\n\n")

# Load data
cat("Loading Lima report data...\n")
tryCatch({
  # Load only the relevant columns from the TSV data
  selected_data <- read_tsv(opt$input, 
                            col_select = c(ZMW, ReadLengths, NumPasses, PassedFilters, 
                                         IdxFirstNamed, IdxCombinedNamed),
                            show_col_types = FALSE)
}, error = function(e) {
  cat("Error reading input file:", e$message, "\n")
  quit(status = 1)
})

cat("Loaded", nrow(selected_data), "records\n")

# Create additional text column with concatenation: IdxFirstNamed + '--' + IdxCombinedNamed
selected_data$CombinedIdx <- paste(selected_data$IdxFirstNamed, selected_data$IdxCombinedNamed, sep = "--")

# Generate histogram plot
cat("Creating size histogram...\n")
p1 <- ggplot(selected_data, aes(x = ReadLengths, fill = factor(PassedFilters), color = factor(PassedFilters))) +
  geom_density(alpha = 0.6) +
  labs(
    title = "Density Distribution of Read Lengths by Filter Status",
    x = "Read Lengths (bp)",
    y = "Density",
    fill = "Passed Filters",
    color = "Passed Filters"
  ) +
  scale_x_continuous(limits = c(opt$`min-size`, opt$`max-size`)) +
  scale_fill_discrete(name = "Passed Filters", labels = c("0" = "Failed", "1" = "Passed")) +
  scale_color_discrete(name = "Passed Filters", labels = c("0" = "Failed", "1" = "Passed")) +
  theme_minimal() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
    legend.position = "bottom"
  )

# Save histogram plot
ggsave("size_histogram.png", plot = p1, width = 10, height = 6, dpi = 300, units = "in")
cat("Saved: size_histogram.png\n")

# Create boxplot for passed filter records only
cat("Creating size boxplot...\n")
passed_data <- selected_data %>% filter(PassedFilters == 1)

if (nrow(passed_data) == 0) {
  cat("Warning: No records passed filters. Skipping boxplot.\n")
} else {
  cat("Using", nrow(passed_data), "passed filter records for boxplot\n")
  
  p2 <- ggplot(passed_data, aes(x = ReadLengths, y = reorder(CombinedIdx, ReadLengths, median))) +
    geom_boxplot(outlier.shape = NA, fill = "lightblue", alpha = 0.7) +
    labs(
      title = "Read Length Distribution by Sample (Passed Filters Only)",
      x = "Read Lengths (bp)",
      y = "Sample"
    ) +
    scale_x_continuous(limits = c(opt$`min-size`, opt$`max-size`)) +
    theme_minimal() +
    theme(
      plot.title = element_text(hjust = 0.5, size = 14, face = "bold"),
      axis.text.y = element_text(size = 8)
    )
  
  # Save boxplot
  ggsave("size_boxplot.png", plot = p2, width = 12, height = 8, dpi = 300, units = "in")
  cat("Saved: size_boxplot.png\n")
}

# Summary statistics
cat("\nSummary Statistics:\n")
cat("==================\n")
total_records <- nrow(selected_data)
passed_records <- sum(selected_data$PassedFilters == 1)
failed_records <- sum(selected_data$PassedFilters == 0)

cat("Total records:", total_records, "\n")
cat("Passed filters:", passed_records, "(", round(passed_records/total_records*100, 1), "%)\n")
cat("Failed filters:", failed_records, "(", round(failed_records/total_records*100, 1), "%)\n")

if (passed_records > 0) {
  passed_lengths <- selected_data$ReadLengths[selected_data$PassedFilters == 1]
  cat("Read length stats (passed):\n")
  cat("  Mean:", round(mean(passed_lengths), 1), "bp\n")
  cat("  Median:", round(median(passed_lengths), 1), "bp\n")
  cat("  Range:", min(passed_lengths), "-", max(passed_lengths), "bp\n")
}

# Save summary statistics to file
cat("Saving summary statistics...\n")
summary_file <- "lima_report_summary.txt"
sink(summary_file)

cat("Lima Report Analysis Summary\n")
cat("===========================\n\n")

cat("Analysis Date:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Command:", paste(commandArgs(), collapse = " "), "\n")
cat("Working Directory:", getwd(), "\n")
cat("Input File:", opt$input, "\n")
cat("Size Range:", opt$`min-size`, "-", opt$`max-size`, "bp\n\n")

cat("Data Summary:\n")
cat("-------------\n")
cat("Total records:", total_records, "\n")
cat("Passed filters:", passed_records, "(", round(passed_records/total_records*100, 1), "%)\n")
cat("Failed filters:", failed_records, "(", round(failed_records/total_records*100, 1), "%)\n\n")

if (passed_records > 0) {
  passed_lengths <- selected_data$ReadLengths[selected_data$PassedFilters == 1]
  cat("Read Length Statistics (Passed Filters Only):\n")
  cat("---------------------------------------------\n")
  cat("Mean:", round(mean(passed_lengths), 1), "bp\n")
  cat("Median:", round(median(passed_lengths), 1), "bp\n")
  cat("Standard Deviation:", round(sd(passed_lengths), 1), "bp\n")
  cat("Minimum:", min(passed_lengths), "bp\n")
  cat("Maximum:", max(passed_lengths), "bp\n")
  cat("Range:", min(passed_lengths), "-", max(passed_lengths), "bp\n")
  cat("Q1 (25th percentile):", round(quantile(passed_lengths, 0.25), 1), "bp\n")
  cat("Q3 (75th percentile):", round(quantile(passed_lengths, 0.75), 1), "bp\n")
  cat("IQR:", round(IQR(passed_lengths), 1), "bp\n\n")
  
  # Sample breakdown
  sample_stats <- passed_data %>%
    group_by(CombinedIdx) %>%
    summarise(
      count = n(),
      mean_length = round(mean(ReadLengths), 1),
      median_length = round(median(ReadLengths), 1),
      .groups = 'drop'
    ) %>%
    arrange(desc(count))
  
  cat("Top 10 Samples by Read Count (Passed Filters):\n")
  cat("----------------------------------------------\n")
  top_n <- min(10, nrow(sample_stats))
  if (top_n > 0) {
    for (i in seq_len(top_n)) {
      cat(sprintf("%-40s %6d reads, mean: %6.1f bp, median: %6.1f bp\n", 
                  sample_stats$CombinedIdx[i], 
                  sample_stats$count[i], 
                  sample_stats$mean_length[i], 
                  sample_stats$median_length[i]))
    }
  }
} else {
  cat("No records passed filters - no read length statistics available.\n")
}

cat("\nOutput Files Generated:\n")
cat("----------------------\n")
cat("- size_histogram.png: Density plot of read lengths by filter status\n")
cat("- size_boxplot.png: Boxplot of read lengths by sample (passed filters only)\n")
cat("- lima_report_summary.txt: This summary file\n\n")

cat("Analysis completed:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")

sink()
cat("Saved: lima_report_summary.txt\n")

cat("\nVisualization complete!\n")