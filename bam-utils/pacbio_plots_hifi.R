#!/usr/bin/Rscript

# Plot from PacBio HiFi BAM
# usage: pacbio_plots_hifi.R <output of hifiBam2metrics_auto.sh on HiFi bam>
# find . -name "*_hifi_metrics.txt" | parallel -j 4 pacbio_plots_hifi.R -i {}
# Stephane Plaisance VIB-NC September-16-2022 v1.0
# October 2023 - version 1.1: add Qvalues and PNG output, and fix syntax changes
# September 2025 added avg and median

# R libraries
suppressMessages(library("optparse"))
suppressMessages(library("readr"))
suppressMessages(library("plyr"))
suppressMessages(library("ggplot2"))
suppressMessages(library("ggpubr"))

option_list = list(
  make_option(c("-i", "--infile"), type="character", default=NULL, 
              help="bam2sizedist.sh output text file", metavar="character")
  ); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$infile)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

##############################
# hifi
##############################

data <- read_csv(opt$infile, show_col_types = FALSE)
# Calculate Qvalue safely, handling edge cases
data$Qvalue <- ifelse(data$Accuracy >= 1.0, 60, -10*log10(1-data$Accuracy))

# Store original count before filtering
total_reads_before <- nrow(data)

# Remove any remaining non-finite values for plotting
data <- data[is.finite(data$len) & is.finite(data$Qvalue) & is.finite(data$bcqual) & is.finite(data$npass), ]

# Calculate dropped reads
total_reads_after <- nrow(data)
dropped_reads <- total_reads_before - total_reads_after

cat("Data summary after filtering:\n")
cat("Total reads before filtering:", total_reads_before, "\n")
cat("Total reads after filtering:", total_reads_after, "\n")
if(dropped_reads > 0) {
  cat("Dropped reads (non-finite values):", dropped_reads, "(", round(100*dropped_reads/total_reads_before, 2), "%)\n")
}
cat("Length range:", min(data$len), "-", max(data$len), "\n")
cat("Qvalue range:", min(data$Qvalue), "-", max(data$Qvalue), "\n")
cat("Pass number range:", min(data$npass), "-", max(data$npass), "\n")
cat("Barcode quality range:", min(data$bcqual), "-", max(data$bcqual), "\n")

p1 <- ggplot(data, aes(x=len, y=Qvalue)) + 
  geom_point(pch=20, cex=0.75, col="grey60", alpha=0.5) + # Add points on top with transparency
  stat_density_2d(aes(fill = after_stat(level)), geom = "polygon", contour = TRUE) + # Use contour for polygons
  scale_fill_gradient(low="blue", high="red") + # Color gradient for density
  labs(x = "CCS len", y = "CCS Qvalue") +
  ggtitle(paste0("sample: ",gsub("_hifi_metrics.txt", "", basename(opt$infile)))) +
  coord_cartesian(ylim = c(0, 60)) + # Limit Qvalue display to reasonable range
  theme_minimal() # Optional: Apply a minimal theme for better aesthetics

p2 <- ggplot(data, aes(x=len, y=bcqual)) + 
  geom_point(pch=20, cex=0.75, col="grey60", alpha=0.5) + # Add points on top with transparency
  geom_bin2d() +
  scale_fill_gradient(low="blue", high="red") + # Color gradient for density
  labs(x = "CCS len", y = "CCS bc quality") +
  ggtitle(paste0("read-count: ", nrow(data))) +
  theme_minimal() # Optional: Apply a minimal theme for better aesthetics

p3 <- ggplot(data, aes(x=npass, y=bcqual)) + 
  geom_point(pch=20, cex=0.75, col="grey60", alpha=0.5) + # Add points on top with transparency
  geom_bin2d() +
  scale_fill_gradient(low="blue", high="red") + # Color gradient for density
  labs(x = "CCS numpass", y = "CCS bc quality") +
  theme_minimal() # Optional: Apply a minimal theme for better aesthetics

p4 <- ggplot(data, aes(x=len, y=npass)) + 
  geom_point(pch=20, cex=0.75, col="grey60", alpha=0.5) + # Add points on top with transparency
  geom_bin2d() +
  scale_fill_gradient(low="blue", high="red") + # Color gradient for density
  labs(x = "CCS len", y = "CCS numpass") +
  theme_minimal() # Optional: Apply a minimal theme for better aesthetics

p5 <- ggplot() + 
  geom_density(data=data, aes(len, colour="blue"), lwd=1.25, show.legend=FALSE) +
  labs(x = "CCS len", y = "density") +
  ggtitle(paste0("CCS length (avg: ", round(mean(data$len[is.finite(data$len)], na.rm=TRUE), 1), ", median: ", round(median(data$len[is.finite(data$len)], na.rm=TRUE), 1), ")")) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white"))

p6 <- ggplot() + 
  geom_density(data=data, aes(npass, colour="blue"), lwd=1.25, show.legend=FALSE) +
  labs(x = "CCS pass number", y = "density") +
  ggtitle(paste0("CCS pass number (avg: ", round(mean(data$npass[is.finite(data$npass)], na.rm=TRUE), 1), ", median: ", round(median(data$npass[is.finite(data$npass)], na.rm=TRUE), 1), ")")) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white"))

p7 <- ggplot() + 
  geom_density(data=data, aes(bcqual, colour="blue"), lwd=1.25, show.legend=FALSE) +
  labs(x = "CCS barcode quality", y = "density") +
  ggtitle(paste0("CCS barcode quality (avg: ", round(mean(data$bcqual[is.finite(data$bcqual)], na.rm=TRUE), 1), ", median: ", round(median(data$bcqual[is.finite(data$bcqual)], na.rm=TRUE), 1), ")")) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white"))

p8 <- ggplot() + 
  geom_density(data=data, aes(Qvalue, colour="blue"), lwd=1.25, show.legend=FALSE) +
  labs(x = "CCS Qvalue", y = "density") +
  ggtitle(paste0("CCS Qvalue (avg: ", round(mean(data$Qvalue[is.finite(data$Qvalue)], na.rm=TRUE), 1), ", median: ", round(median(data$Qvalue[is.finite(data$Qvalue)], na.rm=TRUE), 1), ")")) +
  theme_minimal() +
  theme(panel.background = element_rect(fill = "white"))
  
# print hifi plots
plotfile <- gsub("_hifi_metrics.txt", "_plots.png", basename(opt$infile))

png(plotfile, width = 1600, height = 2400, res = 150)

ggarrange(p1, p2, p3, p4, p5, p6, p7, p8,
          labels = c("A", "B", "C", "D", "E", "F", "G", "H"),
          ncol = 2, nrow = 4)

null <- dev.off()
