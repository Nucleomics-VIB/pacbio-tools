#!/usr/bin/env Rscript

#' 16S Re-run Simulator Script
#' 
#' This script parses bc0X_HiFi.lima.counts files from PacBio HiFi 16S sequencing data
#' and performs comprehensive analysis comparing original counts vs simulated re-run counts
#' across multiple cutoff thresholds. It generates summary statistics, visualizations, and
#' formatted tables to evaluate sample performance.
#' 
#' The script simulates a re-run of the same libraries by doubling the original counts
#' (2*counts) to assess potential improvements in sample yield. This comparison helps
#' evaluate whether re-running libraries would provide sufficient reads to meet quality
#' thresholds.
#' 
#' The script recursively searches for files matching the pattern bc0[0-9]_HiFi.lima.counts
#' in the specified directory structure and analyzes count distributions using cutoffs
#' of 6000, 8000, 10000, and 12000 reads.
#' 
#' @author SP@NC (+AI)
#' @version 1.0.0
#' @date 2025-06-25
#' 
#' @usage Rscript 16S_rerun_simulator.R [options]
#' @param -f, --folder   Path to folder containing lima.counts files (required)
#' @param -m, --maxvalue Maximum value for histogram x-axis (log10 scale) [default: 100000]
#' @param -p, --project  Experiment/project identifier [default: Unknown]
#' @param -h, --help     Display this help message and exit
#' 
#' @examples
#' Rscript 16S_rerun_simulator.R -f /path/to/run/folder
#' Rscript 16S_rerun_simulator.R --folder /path/to/run/folder
#' Rscript 16S_rerun_simulator.R -f /path/to/run/folder -m 50000
#' Rscript 16S_rerun_simulator.R -f /path/to/run/folder -p "Experiment_001"
#' Rscript 16S_rerun_simulator.R -h

# Load required libraries
if (!require("pacman", quietly = TRUE)) {
  install.packages("pacman")
  library(pacman)
}

pacman::p_load(
  optparse,
  dplyr,
  stringr,
  purrr,
  ggplot2,
  gridExtra,
  grid,
  knitr,
  kableExtra,
  tidyr,
  scales
)

# Suppress warnings and messages for cleaner output
options(warn = -1)  # Suppress warnings
options(dplyr.summarise.inform = FALSE)  # Suppress dplyr messages

# Define command line options
option_list <- list(
  make_option(c("-f", "--folder"), 
              type = "character", 
              default = NULL,
              help = "Path to folder containing lima.counts files [required]",
              metavar = "PATH"),
  make_option(c("-m", "--maxvalue"), 
              type = "numeric", 
              default = 100000,
              help = "Maximum value for histogram x-axis (log10 scale) [default: %default]",
              metavar = "NUMBER"),
  make_option(c("-p", "--project"), 
              type = "character", 
              default = "Unknown",
              help = "Experiment/project identifier [default: %default]",
              metavar = "ID")
)

# Parse command line arguments
opt_parser <- OptionParser(
  option_list = option_list,
  description = paste(
    "16S Re-run Simulator Script v1.0.0\n",
    "SP@NC (+AI) - 2025-06-25\n\n",
    "This script analyzes bc0X_HiFi.lima.counts files from PacBio HiFi 16S sequencing data.",
    "It compares original counts vs simulated re-run counts (2x original) across multiple",
    "cutoff thresholds and generates comprehensive statistics, visualizations, and formatted tables.",
    "The 2x counts simulation helps evaluate whether re-running the same libraries would",
    "provide sufficient reads to meet quality thresholds.\n\n",
    "The script recursively searches for files matching bc0[0-9]_HiFi.lima.counts pattern",
    "and analyzes count distributions using cutoffs of 6000, 8000, 10000, and 12000 reads.",
    sep = "\n"
  ),
  epilogue = paste(
    "Examples:",
    "  Rscript 16S_rerun_simulator.R -f /path/to/run/folder",
    "  Rscript 16S_rerun_simulator.R --folder /path/to/run/folder",
    "  Rscript 16S_rerun_simulator.R -f /path/to/run/folder -m 50000",
    "  Rscript 16S_rerun_simulator.R -f /path/to/run/folder -p 'Experiment_001'",
    "",
    "Output files:",
    "  - Individual plots and component PDFs: plots/counts_vs_2x_analysis_*.png/pdf",
    "  - Combined simulation report: simulation_report_<project_id>.pdf (current folder)", 
    "  - Console output with summary tables and statistics",
    "",
    "The 2x counts represent a simulation of re-running the same libraries to assess",
    "potential improvements in sample yield and quality threshold compliance.",
    "The histogram plot uses log10 scaling with configurable maximum value.",
    "",
    "For more information, visit: https://github.com/Nucleomics-VIB",
    sep = "\n"
  )
)

opt <- parse_args(opt_parser)

# Display help if requested or if no folder specified
if (is.null(opt$folder)) {
  print_help(opt_parser)
  quit(save = "no", status = 1)
}

# Validate folder path
if (!dir.exists(opt$folder)) {
  cat("Error: Specified folder does not exist:", opt$folder, "\n")
  quit(save = "no", status = 1)
}

# Validate max_value parameter
if (!is.numeric(opt$maxvalue) || opt$maxvalue <= 0) {
  cat("Error: Maximum value must be a positive number, got:", opt$maxvalue, "\n")
  quit(save = "no", status = 1)
}

cat("16S Re-run Simulator Script v1.0.0\n")
cat("SP@NC (+AI) - 2025-06-25\n")
cat("========================================\n")
cat("Project ID:", opt$project, "\n")
cat("Analyzing folder:", opt$folder, "\n")
cat("Histogram max value:", scales::comma(opt$maxvalue), "\n")
cat("Working directory:", getwd(), "\n\n")

# Function to parse folders and analyze lima counts files
analyze_lima_counts <- function(root_folder) {
  
  # Find all bc0X_HiFi.lima.counts files recursively
  pattern <- "bc0[0-9]_HiFi\\.lima\\.counts$"
  files <- list.files(root_folder, pattern = pattern, recursive = TRUE, full.names = TRUE)
  
  if (length(files) == 0) {
    stop("No bc0X_HiFi.lima.counts files found in the specified folder")
  }
  
  cat("Found", length(files), "lima.counts files\n")
  
  # Initialize list to store data frames
  data_frames <- list()
  
  # Initialize list to store individual tables
  individual_tables <- list()
  
  # Define cutoffs
  cutoffs <- c(6000, 8000, 10000, 12000)
  
  # Process each file
  for (file_path in files) {
    
    # Extract parent folder name and file name for unique naming
    parent_folder <- basename(dirname(file_path))
    file_name <- tools::file_path_sans_ext(basename(file_path))
    df_name <- paste(parent_folder, file_name, sep = "_")
    
    cat("Processing:", file_path, "\n")
    cat("Data frame name:", df_name, "\n")
    
    # Read the TSV file
    tryCatch({
      df <- read.table(file_path, header = TRUE, sep = "\t", stringsAsFactors = FALSE)
      
      # Add column with 2x the Counts value (simulating re-run of same libraries)
      df$Counts_2x <- 2 * df$Counts
      
      # Store the data frame
      data_frames[[df_name]] <- df
      
      # Create summary table for this file - both original and simulated re-run counts
      summary_table <- data.frame(
        cutoff = cutoffs,
        # Original Counts analysis
        counts_greater_equal = sapply(cutoffs, function(x) sum(df$Counts >= x)),
        counts_less_than = sapply(cutoffs, function(x) sum(df$Counts < x)),
        # Simulated re-run (2*Counts) analysis
        counts_2x_greater_equal = sapply(cutoffs, function(x) sum(df$Counts_2x >= x)),
        counts_2x_less_than = sapply(cutoffs, function(x) sum(df$Counts_2x < x))
      )
      
      # Add file identifier
      summary_table$file <- df_name
      summary_table$total_rows <- nrow(df)
      
      # Store individual table
      individual_tables[[df_name]] <- summary_table
      
      cat("  Rows processed:", nrow(df), "\n")
      cat("  Original counts >= 5000:", sum(df$Counts >= 5000), "rows\n")
      cat("  Simulated re-run >= 5000:", sum(df$Counts_2x >= 5000), "rows\n\n")
      
    }, error = function(e) {
      cat("Error processing file", file_path, ":", e$message, "\n")
    })
  }
  
  # Print individual tables
  cat("\n=== INDIVIDUAL FILE SUMMARIES ===\n")
  for (name in names(individual_tables)) {
    cat("\nFile:", name, "\n")
    table_subset <- individual_tables[[name]][, c("cutoff", "counts_greater_equal", "counts_less_than", 
                                                   "counts_2x_greater_equal", "counts_2x_less_than")]
    colnames(table_subset) <- c("Cutoff", "Original>=", "Original<", "Re-run>=", "Re-run<")
    print(table_subset)
  }
  
  # Create merged summary table
  if (length(individual_tables) > 0) {
    
    # Combine all individual tables
    combined_table <- do.call(rbind, individual_tables)
    
    # Create overall summary for both original and simulated re-run counts
    summary_overall_counts <- combined_table %>%
      group_by(cutoff) %>%
      summarise(
        counts_total_greater_equal = sum(counts_greater_equal),
        counts_total_less_than = sum(counts_less_than),
        counts_2x_total_greater_equal = sum(counts_2x_greater_equal),
        counts_2x_total_less_than = sum(counts_2x_less_than),
        total_files = n(),
        .groups = 'drop'
      )
    
    cat("\n=== OVERALL SUMMARY TABLE ===\n")
    cat("Summary across all", length(individual_tables), "files:\n")
    print(summary_overall_counts)
    
    # Additional statistics
    cat("\n=== ADDITIONAL STATISTICS ===\n")
    total_rows_all_files <- sum(sapply(data_frames, nrow))
    cat("Total rows across all files:", total_rows_all_files, "\n")
    
    # Show files processed
    cat("\nFiles processed:\n")
    for (i in seq_along(names(data_frames))) {
      cat(sprintf("%d. %s (%d rows)\n", i, names(data_frames)[i], nrow(data_frames[[names(data_frames)[i]]])))
    }
  }
  
  # Return results as a list
  return(list(
    data_frames = data_frames,
    individual_tables = individual_tables,
    summary_table = if(exists("summary_overall_counts")) summary_overall_counts else NULL,
    files_processed = files
  ))
}

# Function to create visualizations of the final summary table
visualize_summary <- function(results, max_value = 100000) {
  
  if (is.null(results$summary_table)) {
    cat("No summary table to visualize.\n")
    return()
  }
  
  summary_df <- results$summary_table
  
  # Prepare data for plotting - reshape for comparison
  # Create comparison data for original counts vs simulated re-run counts
  comparison_data <- summary_df %>%
    select(cutoff, counts_total_greater_equal, counts_2x_total_greater_equal) %>%
    pivot_longer(cols = c(counts_total_greater_equal, counts_2x_total_greater_equal),
                 names_to = "type", values_to = "count") %>%
    mutate(type = ifelse(type == "counts_total_greater_equal", "Original Counts", "Simulated Re-run"))
  
  # 1. Comparison bar plot - Original vs Simulated Re-run
  p1 <- ggplot(comparison_data, aes(x = factor(cutoff), y = count, fill = type)) +
    geom_col(position = "dodge", alpha = 0.8) +
    labs(title = "Comparison: Original Counts vs Simulated Re-run",
         subtitle = "Number of samples meeting each cutoff threshold",
         x = "Cutoff Value",
         y = "Number of Samples ≥ Cutoff",
         fill = "Count Type") +
    scale_fill_manual(values = c("Original Counts" = "darkblue", "Simulated Re-run" = "red")) +
    scale_x_discrete(labels = function(x) scales::comma(as.numeric(x))) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "top")
  
  # 2. Stacked bar showing distribution for simulated re-run
  summary_df$total_samples <- summary_df$counts_2x_total_greater_equal + summary_df$counts_2x_total_less_than
  summary_df$pct_2x_greater_equal <- (summary_df$counts_2x_total_greater_equal / summary_df$total_samples) * 100
  summary_df$pct_2x_less_than <- (summary_df$counts_2x_total_less_than / summary_df$total_samples) * 100
  
  summary_long <- summary_df %>%
    select(cutoff, pct_2x_greater_equal, pct_2x_less_than) %>%
    pivot_longer(cols = c(pct_2x_greater_equal, pct_2x_less_than), 
                 names_to = "category", values_to = "percentage") %>%
    mutate(category = ifelse(category == "pct_2x_greater_equal", "≥ Cutoff", "< Cutoff"))
  
  p2 <- ggplot(summary_long, aes(x = factor(cutoff), y = percentage, fill = category)) +
    geom_col(position = "stack") +
    labs(title = "Distribution by Simulated Re-run Cutoffs",
         subtitle = "Proportion of samples above/below each threshold (simulated re-run)",
         x = "Cutoff Value",
         y = "Percentage (%)",
         fill = "Category") +
    scale_fill_manual(values = c("≥ Cutoff" = "darkblue", "< Cutoff" = "red")) +
    scale_y_continuous(labels = scales::percent_format(scale = 1)) +
    scale_x_discrete(labels = function(x) scales::comma(as.numeric(x))) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "top")
  
  # 3. Line plot comparing trends
  p3 <- ggplot(comparison_data, aes(x = as.numeric(cutoff), y = count, color = type)) +
    geom_line(size = 1.2) +
    geom_point(size = 3) +
    labs(title = "Trend Comparison: Samples Meeting Cutoffs",
         subtitle = "How original counts vs simulated re-run perform across thresholds",
         x = "Cutoff Value",
         y = "Number of Samples ≥ Cutoff",
         color = "Count Type") +
    scale_color_manual(values = c("Original Counts" = "darkblue", "Simulated Re-run" = "red")) +
    scale_x_continuous(labels = scales::comma_format()) +
    theme_minimal() +
    theme(axis.text.x = element_text(angle = 45, hjust = 1),
          legend.position = "top")
  
  # 4. Individual file comparison (if multiple files)
  if (length(results$individual_tables) > 1) {
    # Create file-by-file comparison
    file_data <- do.call(rbind, results$individual_tables) %>%
      select(file, cutoff, counts_greater_equal, counts_2x_greater_equal) %>%
      pivot_longer(cols = c(counts_greater_equal, counts_2x_greater_equal),
                   names_to = "type", values_to = "count") %>%
      mutate(type = ifelse(type == "counts_greater_equal", "Original Counts", "Simulated Re-run"))
    
    p4 <- ggplot(file_data, aes(x = factor(cutoff), y = count, fill = type)) +
      geom_col(position = "dodge", alpha = 0.8) +
      facet_wrap(~file, scales = "free_y", ncol = 2) +
      labs(title = "Individual File Comparison",
           subtitle = "Original vs Simulated Re-run performance by file",
           x = "Cutoff Value",
           y = "Number of Samples ≥ Cutoff",
           fill = "Count Type") +
      scale_fill_manual(values = c("Original Counts" = "darkblue", "Simulated Re-run" = "red")) +
      scale_x_discrete(labels = function(x) scales::comma(as.numeric(x))) +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 45, hjust = 1),
            legend.position = "top",
            strip.text = element_text(size = 8))
    
    # 5. Add histogram comparison of all counts
    all_counts_data <- create_histogram_data(results)
    
    if (!is.null(all_counts_data)) {
      # Filter data to max_value for better visualization
      all_counts_data_filtered <- all_counts_data[all_counts_data$counts <= max_value, ]
      
      p5 <- ggplot(all_counts_data_filtered, aes(x = counts, fill = type)) +
        geom_histogram(alpha = 0.6, position = "identity", bins = 50) +
        labs(title = "Distribution of Read Counts: Original vs Simulated Re-run",
             subtitle = paste("Frequency histogram (log10 scale, max value:", scales::comma(max_value), ")"),
             x = "Read Counts (log10 scale)",
             y = "Frequency",
             fill = "Count Type") +
        scale_fill_manual(values = c("Original Counts" = "darkblue", "Simulated Re-run" = "red")) +
        scale_x_log10(labels = scales::comma_format(), limits = c(1, max_value),
                      breaks = scales::trans_breaks("log10", function(x) 10^x),
                      minor_breaks = scales::trans_breaks("log10", function(x) 10^x, n = 10)) +
        annotation_logticks(sides = "b") +
        theme_minimal() +
        theme(legend.position = "top")
      
      # Suppress plot output to console
      invisible(suppressMessages(print(p5)))
      
      # Return all plots including the histogram
      return(list(comparison_plot = p1, percentage_plot = p2, trend_plot = p3, 
                   file_comparison = p4, histogram_plot = p5))
    } else {
      # Display all plots except histogram - suppress output
      invisible(suppressMessages(print(p1)))
      invisible(suppressMessages(print(p2)))
      invisible(suppressMessages(print(p3)))
      invisible(suppressMessages(print(p4)))
      
      return(list(comparison_plot = p1, percentage_plot = p2, trend_plot = p3, 
                   file_comparison = p4))
    }
  } else {
    # Display plots for single file - suppress output
    invisible(suppressMessages(print(p1)))
    invisible(suppressMessages(print(p2)))
    invisible(suppressMessages(print(p3)))
    
    return(list(comparison_plot = p1, percentage_plot = p2, trend_plot = p3))
  }
}

# Function to create a formatted table
create_formatted_table <- function(results) {
  
  if (is.null(results$summary_table)) {
    cat("No summary table to format.\n")
    return()
  }
  
  summary_df <- results$summary_table
  
  # Calculate percentages for both original and simulated re-run counts
  summary_df$total_samples_counts <- summary_df$counts_total_greater_equal + summary_df$counts_total_less_than
  summary_df$total_samples_2x <- summary_df$counts_2x_total_greater_equal + summary_df$counts_2x_total_less_than
  
  summary_df$pct_counts_greater_equal <- round((summary_df$counts_total_greater_equal / summary_df$total_samples_counts) * 100, 1)
  summary_df$pct_2x_greater_equal <- round((summary_df$counts_2x_total_greater_equal / summary_df$total_samples_2x) * 100, 1)
  
  # Create a comprehensive formatted table
  formatted_table <- summary_df %>%
    mutate(
      cutoff_formatted = scales::comma(cutoff),
      `Original ≥ Cutoff` = paste0(scales::comma(counts_total_greater_equal), " (", pct_counts_greater_equal, "%)"),
      `Original < Cutoff` = scales::comma(counts_total_less_than),
      `Re-run ≥ Cutoff` = paste0(scales::comma(counts_2x_total_greater_equal), " (", pct_2x_greater_equal, "%)"),
      `Re-run < Cutoff` = scales::comma(counts_2x_total_less_than),
      `Total Files` = total_files
    ) %>%
    select(
      `Cutoff Value` = cutoff_formatted,
      `Original ≥ Cutoff`,
      `Original < Cutoff`,
      `Re-run ≥ Cutoff`,
      `Re-run < Cutoff`,
      `Total Files`
    )
  
  # Print formatted table - completely suppress HTML output
  cat("\n=== COMPREHENSIVE FORMATTED SUMMARY TABLE ===\n")
  invisible(capture.output({
    print(kable(formatted_table, 
                caption = "Comparison of Original Counts vs Simulated Re-run by Cutoff Thresholds",
                align = c("r", "c", "c", "c", "c", "c")) %>%
          kable_styling(bootstrap_options = c("striped", "hover", "condensed")))
  }))
  
  # Create separate summary comparing effectiveness
  effectiveness_table <- summary_df %>%
    mutate(
      cutoff_formatted = scales::comma(cutoff),
      `Original Success Rate` = paste0(pct_counts_greater_equal, "%"),
      `Re-run Success Rate` = paste0(pct_2x_greater_equal, "%"),
      `Improvement Factor` = round(counts_2x_total_greater_equal / pmax(counts_total_greater_equal, 1), 2)
    ) %>%
    select(
      `Cutoff Value` = cutoff_formatted,
      `Original Success Rate`,
      `Re-run Success Rate`,
      `Improvement Factor`
    )
  
  cat("\n=== EFFECTIVENESS COMPARISON TABLE ===\n")
  invisible(capture.output({
    print(kable(effectiveness_table,
                caption = "Success Rate Comparison and Improvement Factor",
                align = c("r", "c", "c", "c")) %>%
          kable_styling(bootstrap_options = c("striped", "hover", "condensed")))
  }))
  
  return(list(main_table = formatted_table, effectiveness_table = effectiveness_table))
}

# Function to save visualizations
save_visualizations <- function(plots, filename_prefix = "lima_analysis") {
  
  # Create plot folder if it doesn't exist
  plot_folder <- "plots"
  if (!dir.exists(plot_folder)) {
    dir.create(plot_folder, recursive = TRUE)
    cat("Created plots folder:", plot_folder, "\n")
  }
  
  # Save individual plots as PNG in the plots folder
  ggsave(file.path(plot_folder, paste0(filename_prefix, "_comparison_plot.png")), plots$comparison_plot, 
         width = 12, height = 8, dpi = 300)
  ggsave(file.path(plot_folder, paste0(filename_prefix, "_percentage_plot.png")), plots$percentage_plot, 
         width = 10, height = 6, dpi = 300)
  ggsave(file.path(plot_folder, paste0(filename_prefix, "_trend_plot.png")), plots$trend_plot, 
         width = 10, height = 6, dpi = 300)
  
  # Save histogram plot in plots folder
  if (!is.null(plots$histogram_plot)) {
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_histogram_plot.png")), plots$histogram_plot, 
           width = 12, height = 8, dpi = 300)
  }
  
  # Save file comparison plot if it exists in plots folder
  if (!is.null(plots$file_comparison)) {
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_file_comparison.png")), plots$file_comparison, 
           width = 14, height = 10, dpi = 300)
    
    # Create separate pages for better readability when many files
    # Page 1: Global summary plots (3 main plots in 2x2 grid)
    global_plot <- grid.arrange(plots$comparison_plot, plots$percentage_plot, plots$trend_plot,
                                layout_matrix = rbind(c(1, 2), c(3, NA)),
                                heights = c(1, 1))
    
    # Page 2: Individual file analysis plots
    if (!is.null(plots$histogram_plot)) {
      # Layout: file comparison on left, histogram plot 2x tall on right
      individual_plot <- grid.arrange(plots$file_comparison, plots$histogram_plot,
                                     layout_matrix = rbind(c(1, 2), c(1, 2)),
                                     widths = c(1, 1), heights = c(1, 1))
    } else {
      # Only file comparison plot
      individual_plot <- plots$file_comparison
    }
    
    # Combine both pages into a list for the simulation report
    combined_plot <- list(global_plot = global_plot, individual_plot = individual_plot)
    
  } else {
    # Create a single page with global plots (no file comparison)
    if (!is.null(plots$histogram_plot)) {
      # Layout: 3 global plots on left, histogram plot 2x tall on right
      combined_plot <- grid.arrange(plots$comparison_plot, plots$percentage_plot, 
                                   plots$trend_plot, plots$histogram_plot,
                                   layout_matrix = rbind(c(1, 4), c(2, 4), c(3, 4)),
                                   heights = c(1, 1, 1))
    } else {
      combined_plot <- grid.arrange(plots$comparison_plot, plots$percentage_plot, plots$trend_plot, 
                                   ncol = 1, heights = c(1, 1, 1))
    }
  }
  
  # Save combined plot as PNG and PDF in plots folder
  if (is.list(combined_plot) && !is.null(combined_plot$global_plot)) {
    # Two-page layout: save both pages separately
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined_global.png")), combined_plot$global_plot, 
           width = 12, height = 16, dpi = 300)
    
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined_global.pdf")), combined_plot$global_plot, 
           width = 12, height = 16, device = "pdf")
    
    if (!is.null(combined_plot$individual_plot)) {
      ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined_individual.png")), combined_plot$individual_plot, 
             width = 16, height = 10, dpi = 300)
      
      ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined_individual.pdf")), combined_plot$individual_plot, 
             width = 16, height = 10, device = "pdf")
    }
  } else {
    # Single-page layout: save as before
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined.png")), combined_plot, 
           width = 16, height = 20, dpi = 300)
    
    ggsave(file.path(plot_folder, paste0(filename_prefix, "_combined.pdf")), combined_plot, 
           width = 16, height = 20, device = "pdf")
  }
  
  cat("Individual plots saved to folder:", plot_folder, "\n")
  cat("Individual plot files created:\n")
  cat("- ", file.path(plot_folder, paste0(filename_prefix, "_comparison_plot.png")), "\n", sep = "")
  cat("- ", file.path(plot_folder, paste0(filename_prefix, "_percentage_plot.png")), "\n", sep = "")
  cat("- ", file.path(plot_folder, paste0(filename_prefix, "_trend_plot.png")), "\n", sep = "")
  if (!is.null(plots$histogram_plot)) {
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_histogram_plot.png")), "\n", sep = "")
  }
  if (!is.null(plots$file_comparison)) {
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_file_comparison.png")), "\n", sep = "")
  }
  
  # Report combined plot files based on structure
  if (is.list(combined_plot) && !is.null(combined_plot$global_plot)) {
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined_global.png")), "\n", sep = "")
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined_global.pdf")), "\n", sep = "")
    if (!is.null(combined_plot$individual_plot)) {
      cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined_individual.png")), "\n", sep = "")
      cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined_individual.pdf")), "\n", sep = "")
    }
  } else {
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined.png")), "\n", sep = "")
    cat("- ", file.path(plot_folder, paste0(filename_prefix, "_combined.pdf")), "\n", sep = "")
  }
  
  # Return the combined plot for the simulation report
  return(combined_plot)
}

# Function to save tables as PDF
save_tables_pdf <- function(formatted_tables, filename_prefix = "lima_analysis") {
  
  if (is.null(formatted_tables)) {
    cat("No tables to save.\n")
    return()
  }
  
  # Create a PDF file for tables in plots folder
  pdf_filename <- file.path("plots", paste0(filename_prefix, "_tables.pdf"))
  
  # Load required library for PDF table generation
  pacman::p_load(gridExtra, grid)
  
  pdf(pdf_filename, width = 11, height = 8.5)
  
  # Page 1: Main comprehensive table
  if (!is.null(formatted_tables$main_table)) {
    grid.newpage()
    
    # Title
    grid.text("16S Re-run Simulator - Comprehensive Summary", 
              x = 0.5, y = 0.95, 
              gp = gpar(fontsize = 16, fontface = "bold"))
    
    grid.text("Comparison of Original Counts vs Simulated Re-run by Cutoff Thresholds", 
              x = 0.5, y = 0.90, 
              gp = gpar(fontsize = 12))
    
    # Convert table to grob for better formatting
    table_grob <- tableGrob(formatted_tables$main_table, 
                           theme = ttheme_default(
                             core = list(fg_params = list(cex = 0.8)),
                             colhead = list(fg_params = list(cex = 0.9, fontface = "bold")),
                             rowhead = list(fg_params = list(cex = 0.8))
                           ))
    
    # Center the table
    grid.draw(table_grob)
    
    # Add footer
    grid.text(paste("Generated on:", Sys.Date(), "by 16S Re-run Simulator Script v1.0.0"), 
              x = 0.5, y = 0.05, 
              gp = gpar(fontsize = 8, col = "gray50"))
  }
  
  # Page 2: Effectiveness comparison table
  if (!is.null(formatted_tables$effectiveness_table)) {
    grid.newpage()
    
    # Title
    grid.text("16S Re-run Simulator - Effectiveness Comparison", 
              x = 0.5, y = 0.95, 
              gp = gpar(fontsize = 16, fontface = "bold"))
    
    grid.text("Success Rate Comparison and Improvement Factor", 
              x = 0.5, y = 0.90, 
              gp = gpar(fontsize = 12))
    
    # Convert table to grob
    table_grob <- tableGrob(formatted_tables$effectiveness_table, 
                           theme = ttheme_default(
                             core = list(fg_params = list(cex = 0.8)),
                             colhead = list(fg_params = list(cex = 0.9, fontface = "bold")),
                             rowhead = list(fg_params = list(cex = 0.8))
                           ))
    
    # Center the table
    grid.draw(table_grob)
    
    # Add footer
    grid.text(paste("Generated on:", Sys.Date(), "by 16S Re-run Simulator Script v1.0.0"), 
              x = 0.5, y = 0.05, 
              gp = gpar(fontsize = 8, col = "gray50"))
  }
  
  dev.off()
  
  cat("Tables saved as PDF in plots folder:", pdf_filename, "\n")
  
  # Return the filename for combining with the simulation report
  return(pdf_filename)
}

# Function to create the combined simulation report PDF
create_simulation_report <- function(combined_plot, formatted_tables, project_id = "Unknown", filename = "simulation_report.pdf") {
  
  # Load required library for PDF generation
  pacman::p_load(gridExtra, grid)
  
  # Create the combined simulation report PDF in current folder
  pdf(filename, width = 11, height = 8.5)
  
  # Page 1: Title page with summary
  grid.newpage()
  grid.text("16S Re-run Simulator", 
            x = 0.5, y = 0.9, 
            gp = gpar(fontsize = 24, fontface = "bold"))
  
  grid.text("Comprehensive Analysis Report", 
            x = 0.5, y = 0.85, 
            gp = gpar(fontsize = 16))
  
  grid.text(paste("Generated on:", Sys.Date()), 
            x = 0.5, y = 0.8, 
            gp = gpar(fontsize = 12))
  
  grid.text("SP@NC (+AI) - 2025-06-25", 
            x = 0.5, y = 0.75, 
            gp = gpar(fontsize = 12))
  
  grid.text(paste("Project ID:", project_id), 
            x = 0.5, y = 0.7, 
            gp = gpar(fontsize = 14, fontface = "bold", col = "darkblue"))
  
  # Add summary description
  summary_text <- paste(
    "This report analyzes PacBio HiFi 16S sequencing data by comparing original counts",
    "vs simulated re-run counts (2x original) across multiple cutoff thresholds.",
    "The analysis evaluates whether re-running the same libraries would provide",
    "sufficient reads to meet quality thresholds.",
    "",
    "The report includes:",
    "• Statistical summaries and effectiveness comparisons",
    "• Visualization plots showing count distributions and trends",
    "• Individual file comparisons and histogram analysis",
    "",
    "All individual plot files are available in the plots/ subfolder.",
    sep = "\n"
  )
  
  grid.text(summary_text, 
            x = 0.1, y = 0.45, 
            gp = gpar(fontsize = 11), 
            just = "left")
  
  # Add footer
  grid.text("For more information, visit: https://github.com/Nucleomics-VIB", 
            x = 0.5, y = 0.05, 
            gp = gpar(fontsize = 10, col = "gray50"))
  
  # Page 2: Main comprehensive table
  if (!is.null(formatted_tables$main_table)) {
    grid.newpage()
    
    # Title
    grid.text("Comprehensive Summary Table", 
              x = 0.5, y = 0.95, 
              gp = gpar(fontsize = 16, fontface = "bold"))
    
    grid.text("Comparison of Original Counts vs Simulated Re-run by Cutoff Thresholds", 
              x = 0.5, y = 0.90, 
              gp = gpar(fontsize = 12))
    
    # Convert table to grob for better formatting
    table_grob <- tableGrob(formatted_tables$main_table, 
                           theme = ttheme_default(
                             core = list(fg_params = list(cex = 0.8)),
                             colhead = list(fg_params = list(cex = 0.9, fontface = "bold")),
                             rowhead = list(fg_params = list(cex = 0.8))
                           ))
    
    # Center the table
    grid.draw(table_grob)
    
    # Add footer
    grid.text(paste("Generated on:", Sys.Date(), "by 16S Re-run Simulator Script v1.0.0"), 
              x = 0.5, y = 0.05, 
              gp = gpar(fontsize = 8, col = "gray50"))
  }
  
  # Page 3: Effectiveness comparison table
  if (!is.null(formatted_tables$effectiveness_table)) {
    grid.newpage()
    
    # Title
    grid.text("Effectiveness Comparison", 
              x = 0.5, y = 0.95, 
              gp = gpar(fontsize = 16, fontface = "bold"))
    
    grid.text("Success Rate Comparison and Improvement Factor", 
              x = 0.5, y = 0.90, 
              gp = gpar(fontsize = 12))
    
    # Convert table to grob
    table_grob <- tableGrob(formatted_tables$effectiveness_table, 
                           theme = ttheme_default(
                             core = list(fg_params = list(cex = 0.8)),
                             colhead = list(fg_params = list(cex = 0.9, fontface = "bold")),
                             rowhead = list(fg_params = list(cex = 0.8))
                           ))
    
    # Center the table
    grid.draw(table_grob)
    
    # Add footer
    grid.text(paste("Generated on:", Sys.Date(), "by 16S Re-run Simulator Script v1.0.0"), 
              x = 0.5, y = 0.05, 
              gp = gpar(fontsize = 8, col = "gray50"))
  }
  
  # Page 4: Combined visualization plots
  if (!is.null(combined_plot)) {
    
    # Check if we have a two-page structure or single page
    if (is.list(combined_plot) && !is.null(combined_plot$global_plot)) {
      
      # Page 4: Global summary plots
      grid.newpage()
      grid.text("Global Summary Visualization", 
                x = 0.5, y = 0.95, 
                gp = gpar(fontsize = 16, fontface = "bold"))
      
      # Create a viewport for the global plots
      pushViewport(viewport(x = 0.5, y = 0.47, width = 0.95, height = 0.85))
      grid.draw(combined_plot$global_plot)
      popViewport()
      
      # Page 5: Individual file analysis plots (if available)
      if (!is.null(combined_plot$individual_plot)) {
        grid.newpage()
        grid.text("Individual File Analysis", 
                  x = 0.5, y = 0.95, 
                  gp = gpar(fontsize = 16, fontface = "bold"))
        
        # Create a viewport for the individual plots
        pushViewport(viewport(x = 0.5, y = 0.47, width = 0.95, height = 0.85))
        grid.draw(combined_plot$individual_plot)
        popViewport()
      }
      
    } else {
      # Single page layout (original behavior)
      grid.newpage()
      grid.text("Visualization Summary", 
                x = 0.5, y = 0.95, 
                gp = gpar(fontsize = 16, fontface = "bold"))
      
      # Create a viewport for the plots with proper margins
      pushViewport(viewport(x = 0.5, y = 0.47, width = 0.95, height = 0.85))
      grid.draw(combined_plot)
      popViewport()
    }
  }
  
  dev.off()
  
  cat("Combined simulation report saved as:", filename, "\n")
}

# Function to create histogram data from all counts
create_histogram_data <- function(results) {
  
  if (is.null(results$data_frames) || length(results$data_frames) == 0) {
    cat("No data available for histogram.\n")
    return(NULL)
  }
  
  # Combine all data frames and extract counts
  all_original_counts <- c()
  all_2x_counts <- c()
  
  for (df_name in names(results$data_frames)) {
    df <- results$data_frames[[df_name]]
    all_original_counts <- c(all_original_counts, df$Counts)
    all_2x_counts <- c(all_2x_counts, df$Counts_2x)
  }
  
  # Create combined data frame for plotting
  histogram_data <- data.frame(
    counts = c(all_original_counts, all_2x_counts),
    type = rep(c("Original Counts", "Simulated Re-run"), 
              c(length(all_original_counts), length(all_2x_counts)))
  )
  
  cat("Histogram data created:\n")
  cat("- Original counts:", length(all_original_counts), "samples\n")
  cat("- Simulated re-run counts:", length(all_2x_counts), "samples\n")
  
  return(histogram_data)
}

# Main execution
main <- function() {
  # Set working directory to the specified folder
  original_wd <- getwd()
  setwd(opt$folder)
  
  # Ensure we return to original directory on exit
  on.exit(setwd(original_wd))
  
  # Prevent automatic PDF generation (Rplots.pdf)
  pdf.options(useDingbats = FALSE)
  
  # Run the analysis
  cat("Starting analysis...\n")
  results <- analyze_lima_counts(opt$folder)
  
  cat("\nGenerating visualizations...\n")
  plots <- visualize_summary(results, opt$maxvalue)
  
  cat("\nCreating formatted tables...\n")
  formatted_tables <- create_formatted_table(results)
  
  cat("\nSaving visualizations...\n")
  combined_plot <- save_visualizations(plots, 'counts_vs_2x_analysis')
  
  cat("\nSaving tables as PDF...\n")
  tables_pdf_path <- save_tables_pdf(formatted_tables, 'counts_vs_2x_analysis')
  
  cat("\nCreating combined simulation report...\n")
  # Create filename with project identifier
  report_filename <- paste0("simulation_report_", gsub("[^A-Za-z0-9_-]", "_", opt$project), ".pdf")
  create_simulation_report(combined_plot, formatted_tables, opt$project, report_filename)
  
  # Clean up any accidentally created Rplots.pdf
  if (file.exists("Rplots.pdf")) {
    file.remove("Rplots.pdf")
    cat("Removed Rplots.pdf\n")
  }
  
  cat("\n========================================\n")
  cat("Analysis complete!\n")
  cat("Check the generated files:\n")
  cat("- Individual PNG plots and component PDFs in 'plots/' subfolder\n")
  cat("- Combined simulation report:", report_filename, "(current folder)\n")
  cat("Working directory:", getwd(), "\n")
}

# Execute main function
main()