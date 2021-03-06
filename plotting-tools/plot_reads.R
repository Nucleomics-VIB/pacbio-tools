#!/usr/bin/Rscript

# script: plot_reads.R (SP:NC 2014-07-26)
# Aim: plot read size distributions from the created reads.db files
# adapted from http://pb-falcon.readthedocs.io/en/latest/Rhists.html?highlight=preads.stats.txt

# required; create content in terminal in the working folder with:
# DBstats 0-rawreads/raw_reads.db > raw_reads.stats
# DBstats 1-preads_ovl/preads.db > preads.stats
# then run this code in the working folder

raw <- read.table("raw_reads.stats", header=F, skip=14)
colnames(raw) <- c("Bin","Count","% Reads","% Bases","Average")
raw$Bin <- gsub(":", "", raw$Bin)
raw$Bin <- gsub(",", "", raw$Bin)

pdf(file="RawReadHist.pdf", width=11, height=8.5)
par(oma=c(4,4,2,0), cex=1.6, las=1, mar=c(4,4,2,2))
plot(data=raw, Count~Bin, type="h",col="DeepSkyBlue", lwd=5,
     ylab="", xlab="Read Length", main="Raw Reads")
mtext("Read Count", side=2, cex=1.7, las=3, line=4)
dev.off()

preads <- read.table("preads.stats", header=F, skip=14)
colnames(preads) <- c("Bin","Count","% Reads","% Bases","Average")
preads$Bin <- gsub(":", "", preads$Bin)
preads$Bin <- gsub(",", "", preads$Bin)

pdf(file="PreadHist.pdf", width=11, height=8.5)
par(oma=c(4,4,2,0), cex=1.6, las=1, mar=c(4,4,2,2))
plot(data=preads, Count~Bin, type="h",col="ForestGreen", lwd=5,
     ylab="", xlab="Read Length", main="Preassembled Reads")
mtext("Read Count", side=2, cex=1.7, las=3, line=4)
dev.off()