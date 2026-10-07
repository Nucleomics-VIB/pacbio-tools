#!/usr/bin/Rscript

# script: plot_ovlp-stats.R (SP:NC 2014-07-26)
# Aim: plot overlap size distributions from a created ovlp.stats file
# adapted from http://pb-falcon.readthedocs.io/en/latest/OvlpHists.html#ovlphists
#
# SPDX-License-Identifier: BSD-3-Clause
# Copyright (c) 2019, Pacific Biosciences (the adapted code, from the pb-falcon docs)
# The full licence text is in LICENSES/BSD-3-Clause_PacBio.txt at the repository root.
# This file is NOT covered by the repository's GPL-3.0 licence. See NOTICE.md.

library(ggplot2)
o<-read.table("ovlp.stats", header=F)
colnames(o)<-c("pread","length","fivePrimeOvlps","threePrimeOvlps")

pdf(file="OvlpHist.pdf", width=11, height=5)
par(oma=c(3,3,2,0), cex=1.6, las=1, mar=c(4,4,2,2), mfrow=c(1,2))
hist(o$fivePrimeOvlps, breaks=100,
        xlab="number of overlaps between preads",
        ylab="count", main="Five Prime")
hist(o$threePrimeOvlps, breaks=100,
        xlab="number of overlaps between preads",
        ylab="count", main="Three Prime")
dev.off()