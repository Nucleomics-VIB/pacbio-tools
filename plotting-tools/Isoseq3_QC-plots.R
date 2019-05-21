#!/usr/bin/env Rscript

# script: Isoseq3_QC-plots.R
# create plots from Isoseq3 polished.cluster_report.csv
# SP & Joke A. 2019-05-21 v1.0

# required libraries
suppressMessages(library("readr"))
suppressMessages(library("dplyr"))
suppressMessages(library("ggplot2"))
suppressMessages(library("grid"))
suppressMessages(library("gridExtra"))

args <- commandArgs(trailingOnly=TRUE)
# argument for plot title

if (length(args)==0) {
  title="Isoseq3 QC plots"
} else if (length(args)==1) {
  title <- args[1]
}

polished_cluster_report <- suppressMessages(read_csv("polished.cluster_report.csv"))

# plot CCS support per transcript until 'lim'
hist.data <- polished_cluster_report %>% 
  count(cluster_id)

lim <- 20
p1 <- suppressMessages(ggplot(hist.data[hist.data$n<=lim,], aes(n)) +
  geom_bar() +
  scale_x_continuous(breaks=c(1:lim)) +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("number of supporting CCS reads") +
  ylab("Transcript count"))

# plot novel Transcript saturation
plot.data <- data.frame(CCS_fraction=0, Transcript_count=0)

for (i in seq(0.1, 1, by=0.1)) {
  dat <- sample_frac(polished_cluster_report, i)
  plot.data <- rbind(plot.data, c( i, length(unique(dat$cluster_id))) )
}

p2 <- suppressMessages(ggplot(plot.data, aes(x=CCS_fraction, y=Transcript_count)) +
  scale_x_continuous(labels = scales::percent) +
  geom_smooth(method="loess", se=FALSE, fullrange=TRUE, size=1) +
  geom_point(shape=20, size=4, color="red") +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("CCS fraction") +
  ylab("Transcript count"))

pdf("isoseq3_QC-plots.pdf", onefile = TRUE)
grid.arrange(p1, p2,
	top = textGrob(title, gp=gpar(fontsize=20,font=3)))
null <- dev.off()
