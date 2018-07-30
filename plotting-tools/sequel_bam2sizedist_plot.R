#!/usr/bin/Rscript

# Analysze PacBio Sequel subread BAM counts
# usage: sequel_bam2sizedist_plot.R <output of bam2sizedist.sh on subreads bam>
#
# Stephane Plaisance VIB-NC March-15-2018 v1.0

# R libraries
library("readr")
library("plyr")
library("ggplot2")

args <- commandArgs(trailingOnly=TRUE)

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("output of bam2sizedist.sh on subreads bam is required!.\n", call.=FALSE)
} else if (length(args)==1) {
  infile <- args[1]
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

# run samtools and get result in R to plot
#infile="m54094_180411_025859.subreads_length-dist.txt"
read_info <- read_delim(infile, 
                        ",", escape_double = FALSE, col_names = TRUE, 
                        trim_ws = TRUE,
                        col_types = cols())

# get polymerase as largest end coordinate for each Mol.ID group
polymerase <- ddply(read_info, .(Mol.ID), summarise, maxEnd = max(end))

n50reads <- Nvalue(50,read_info$len)
n50polym <- Nvalue(50,polymerase$maxEnd)

pdf(gsub(".txt",".pdf",basename(infile)), width = 10, height = 6)

ggplot() + 
  geom_density(data=read_info, aes(len, colour="red"), lwd=1.25, show.legend=FALSE) +
  stat_density(data=read_info, aes(len, colour="red"), geom="line", position="identity", lwd=1.25) +
  geom_density(data=polymerase, aes(maxEnd, colour="blue"), lwd=1.25, show.legend=FALSE) +
  scale_x_log10(
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    labels = scales::trans_format("log10", scales::math_format(10^.x))
  ) + annotation_logticks(sides="b") +
  labs(x = "read length", y = "density") +
  geom_vline(aes(xintercept=n50reads), size=0.5, colour="red", lty=2) +
  geom_text(aes(x=n50reads, label=n50reads, y=0.1), colour="red", angle=90, vjust = -0.6) +
  geom_vline(aes(xintercept=n50polym), size=0.5, colour="blue", lty=2) +
  geom_text(aes(x=n50polym, label=n50polym, y=0.1), colour="blue", angle=90, vjust = -0.6) +
  theme(axis.text.x = element_text(colour="grey20",size=12,angle=0,hjust=.5,vjust=.5,face="plain"),
        axis.text.y = element_text(colour="grey20",size=12,angle=0,hjust=1,vjust=0,face="plain"),
        axis.title.x = element_text(colour="grey20",size=12,angle=0,hjust=.5,vjust=0,face="plain"),
        axis.title.y = element_text(colour="grey20",size=12,angle=90,hjust=.5,vjust=.5,face="plain"),
        legend.justification = c(0,1),
        legend.text = element_text(size=12),
        legend.key = element_rect(colour = NA, fill = NA),
        legend.key.size = unit(0.8, "lines"),
        legend.background = element_rect(fill="transparent"),
        plot.title = element_text(margin=margin(b=0), size = 14)) +
  ggtitle("Read density distributions") +
  scale_colour_manual(name = "Sequel reads type", 
                      values =c("blue"="blue","red"="red"), 
                      labels = c("polymerase\n(max.qE)","subreads"))

null <- dev.off()
