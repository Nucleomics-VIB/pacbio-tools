#!/usr/bin/env RScript

# Analysze PacBio Sequel BAM data (subreads and scraps)
# also analyse polymerase reads if produced by pb2polymerase.sh
# collect sequence lengths and make plots
# usage: sequel_read_lengths.R <path to the data>
#
# Stephane Plaisance VIB-NC March-15-2018 v1.0

# R libraries
suppressPackageStartupMessages(library("grid"))
suppressPackageStartupMessages(library("gridBase"))
suppressPackageStartupMessages(library("gridExtra"))
suppressPackageStartupMessages(library("readr"))
suppressPackageStartupMessages(library("dplyr"))
suppressPackageStartupMessages(library("ggplot2"))
#suppressPackageStartupMessages(library("reshape2"))

args <- commandArgs(trailingOnly=TRUE)
# 
# # test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input path).\n", call.=FALSE)
} else if (length(args)==1) {
  infile <- args[1]
}

# custom function
lenstats <- function(x, na.rm = TRUE){
  # handle NA values
  if(isTRUE(na.rm)){
    x <- x[!is.na(x)]
  }
  x <- as.numeric(x)
  # compute L50 and N50
  sorted <- sort(x, decreasing = TRUE)
  S50 <- sum(x)/2
  csum <- cumsum(sorted)
  GTL50 <- as.vector(csum >= S50)
  L50=min(which(GTL50 == TRUE))
  N50 <- round(sorted[L50], 1)
  
  # add more items
  result=c(count=length(x), mean=mean(x), median=median(x), N50=N50, L50=L50)
  # return list
  result
}

outfile=paste(infile, "_median.pdf", sep="")

pdf(file=outfile)

sub <- read.table(infile, sep=",", header=TRUE)

# add poly subread count
count <- dplyr::add_count(sub, Mol.ID, name="pass")
sub <- cbind(sub, pass=count$pass)

# add subread #
sub <- sub %>% arrange(Mol.ID, start) %>% 
  group_by(Mol.ID) %>% 
  mutate(rank = rank(Mol.ID, ties.method = "first"))

# add subread_mean-length
sub <- sub %>% arrange(Mol.ID, start) %>% 
  group_by(Mol.ID) %>% 
  mutate(mean = mean(len))

# add subread_median-length
sub <- sub %>% arrange(Mol.ID, start) %>% 
  group_by(Mol.ID) %>% 
  mutate(median = median(len))

# add subread_max-length
sub <- sub %>% arrange(Mol.ID, start) %>% 
  group_by(Mol.ID) %>% 
  mutate(max = max(len))

# plot densities
dat <- subset(sub, pass<6 & rank==1)
dat$pass <- as.factor(dat$pass)

ggplot(dat, aes(x=median, color=pass, group=pass)) + 
  geom_density(alpha=0.5) +
  xlim(0,50000) +
  xlab("subread median length") + 
  guides(fill=guide_legend(title="Polymerase\nPasses")) + 
  scale_color_brewer(palette="Spectral")

dev.off()

# end
