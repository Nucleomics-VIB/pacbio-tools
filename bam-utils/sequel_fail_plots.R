#!/usr/bin/Rscript

# Plot from PacBio Sequel CCS BAM
# usage: sequel_fail_plots.R <output of hifiBam2metrics.sh on HIFI bam>
#
# Stephane Plaisance VIB-NC September-16-2022 v1.0
# October 2023 - version 1.1: add Qvalues and PNG output, and fix syntax changes

# R libraries
suppressMessages(library("optparse"))
suppressMessages(library("readr"))
suppressMessages(library("plyr"))
suppressMessages(library("ggplot2"))
suppressMessages(library("ggpubr"))

option_list = list(
  make_option(c("-i", "--infile"), type="character", default=NULL, 
              help="bam2sizedist.sh output text file", metavar="character"),
  make_option(c("-p", "--minpass"), type="numeric", default="0", 
              help="minimal number of CCS passes [default= %default]", metavar="numeric"),
  make_option(c("-m", "--minlength"), type="numeric", default="0", 
              help="minimal HiFi length [default= %default]", metavar="numeric"),
  make_option(c("-M", "--maxlength"), type="numeric", default="1000000", 
              help="maximal HiFi length [default= %default]", metavar="numeric"),
  make_option(c("-f", "--format"), type="character", default="png", 
              help="output format (png or pdf) [default= %default]", metavar="character")
); 

opt_parser = OptionParser(option_list=option_list);
opt = parse_args(opt_parser);

if (is.null(opt$infile)){
  print_help(opt_parser)
  stop("At least one argument must be supplied (input file).n", call.=FALSE)
}

Nvalue <- function(lim, x, na.rm = TRUE){
  # handle NA values
  if(isTRUE(na.rm)){
    x <- x[!is.na(x)]
  }
  cutval <- 100/lim
  # compute LXX and NXX
  sorted <- sort(x, decreasing = TRUE)
  SXX <- sum(x)/cutval
  csum <- cumsum(sorted)
  GTLXX <- as.vector(csum >= SXX)
  LXX=min(which(GTLXX == TRUE))
  NXX <- round(sorted[LXX], 1)
  # eg: get NXX with lst['NXX']
  NXX
}

# load data in
ccs_info <- read_delim(opt$infile,
                       ",", escape_double = FALSE, col_names = TRUE, 
                       trim_ws = TRUE,
                       col_types = cols())

# filtered data
ccs_data <- subset(ccs_info, (npass>opt$minpass & len>=opt$minlength & len<=opt$maxlength))

minl <- min(ccs_data$len)
maxl <- max(ccs_data$len)
n50reads <- Nvalue(50,ccs_data$len)
minpass <- min(ccs_data$npass)
maxpass <- max(ccs_data$npass)
n50npass <- Nvalue(50,ccs_data$npass)

# Determine the output file extension based on the chosen format
output_file_extension <- ifelse(opt$format == "pdf", "pdf", "png")

# Save plots in the chosen format (PDF or PNG)
if (opt$format == "pdf") {
  pdf(gsub("_hifi_metrics.txt", paste0("_plots.", output_file_extension), basename(opt$infile)), width = 10, height = 10)
} else {
  png(gsub("_hifi_metrics.txt", paste0("_plots.", output_file_extension), basename(opt$infile)), width = 1600, height = 1600, res = 150)
}

# plot lengths
p1 <- ggplot() + 
  geom_density(data=ccs_data, aes(len, colour="orange"), lwd=1.25, show.legend=FALSE) +
  labs(x = "read length", y = "density") +
  theme_linedraw() +
  theme(plot.title = element_text(margin=margin(b=0), size = 14)) +
  ggtitle(paste0("CCS length ([", minl, "..", maxl, "], N50=" ,n50reads, ")"))

# plot passnumber
p2 <- ggplot() + 
  geom_density(data=ccs_data, aes(npass, colour="blue"), lwd=1.25, show.legend=FALSE) +
  labs(x = "CCS passs number", y = "density") +
  theme_linedraw() +
  theme(plot.title = element_text(margin=margin(b=0), size = 14)) +
  ggtitle(paste0("pass number", " (min=",minpass,", N50=" ,n50npass, ")"))

# biplot npass x length
p3 <- ggplot() + 
    geom_point(data=ccs_data, aes(x=len, y=npass), pch=20, cex=0.75, col="grey60") +
    labs(x = "CCS length", y = "CCS pass number") +
    stat_density_2d(aes(fill = after_stat(level)), geom="polygon") +
    scale_fill_gradient(low="blue", high="red") +
    geom_vline(aes(xintercept=n50reads), linewidth=0.5, colour="blue", lty=2) +
    theme_linedraw() +
    theme(plot.title = element_text(margin=margin(b=0), size = 14),
          legend.position = "none") +
    annotate(geom="text", 
             x=minl+1/4*(maxl-minl), 
             y=minpass+2/3*(maxpass-minpass), 
             label="dashed-blue line N50",
             color="grey25",
             cex=4) +
    ggtitle(paste0("read-count: ", nrow(ccs_data)))

p0 <- ggplot() + 
  theme_void() +  # Removes axes, grid lines, and background
  theme(legend.position = "none")  # Removes legend if present

ggarrange(p1, p0, p3, p2, 
            labels = c("A", "B", "C", "D"),
            ncol = 2, nrow = 2)

null <- dev.off()

