#!/usr/bin/env Rscript

# script: Isoseq3_QC-plots.R
# create plots from Isoseq3 polished.cluster_report.csv
# create plot from Isoseq3 unpolished.cluster
# designed for single smartcell data !
# SP & Joke A. 2019-05-21 v2.1

# required libraries
suppressMessages(library("readr"))
suppressMessages(library("dplyr"))
suppressMessages(library("stringr"))
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

# plot CCS support per transcript until 'lim' to avoid long tail
hist.data <- polished_cluster_report %>%
  count(cluster_id) %>%
  arrange(desc(n)) %>%
  mutate(cum_sum = cumsum(n)) %>%
  mutate(percent = cum_sum/sum(n))

# add table for CCS Nvalues (similar to N50 but whole range of N's)
# X% of the transcripts have Y or more supporting CCS's
cum.data <- data.frame(percent=numeric(), CCS_count=numeric())
for (lim in seq(0, 1, by=0.1)) {
  dat <- hist.data[min(which(hist.data$percent>lim)),]
  cum.data <- rbind(cum.data, c(100*(1-lim), dat$n))
}
colnames(cum.data) <- c("percent", "min_CCS_count")

lim <- 15
p1 <- suppressMessages(ggplot(hist.data[hist.data$n<=lim,], aes(n)) +
  geom_bar() +
  scale_x_continuous(breaks=c(1:lim)) +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("number of supporting CCS reads") +
  ylab("Transcript count"))

# 10x subset 0 to 100% and count unique Transcripts
plot.data <- data.frame(CCS_sample=0, Transcript_count=0)
for (iter in seq(1, 10, by=1)) {
for (i in seq(0.1, 1, by=0.1)) {
  dat <- sample_frac(polished_cluster_report, i)
  plot.data <- rbind(plot.data, c( i, length(unique(dat$cluster_id))) )
}
}

p2 <- suppressMessages(ggplot(plot.data, aes(x=CCS_sample, y=Transcript_count)) +
  scale_x_continuous(labels = scales::percent) +
  geom_smooth(method="loess", se=FALSE, fullrange=TRUE, size=1) +
  geom_point(shape=20, size=4, color="red") +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("CCS sample") +
  ylab("Transcript count (10 random pulls)"))

# load and process unpolished.cluster
pairwise <- suppressMessages(read_table2("unpolished.cluster"))
# simplify content (ony works when data comes from a single Smart-cell)
pairwise$from <- str_replace(pairwise$from, "(.*)_(.*)_(.*)/(.*)/ccs","\\4")
pairwise$to <- str_replace(pairwise$to, "(.*)_(.*)_(.*)/(.*)/ccs","\\4")

# 10x subset 0 to 100% and count n>1
saturation.data <- data.frame(FLNC_sample=numeric(), Cluster_count=numeric())

for (iter in seq(1, 10, by=1)) {
for (sub in seq(0, 1, by=0.1)) {
  data <- sample_frac(pairwise, sub) %>%
    group_by(to) %>%
    summarise(n = n()) %>%
    filter(n > 1) 
  saturation.data <- rbind(saturation.data, c(sub, nrow(data)))
}
}

colnames(saturation.data) <- c("FLNC_sample", "Cluster_count")

p3 <- ggplot(saturation.data, aes(x=FLNC_sample, y=Cluster_count)) +
  scale_x_continuous(labels = scales::percent) +
  geom_smooth(method="loess", se=FALSE, fullrange=TRUE, size=1) +
  geom_point(shape=20, size=4, color="red") +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("FLNC sample") +
  ylab("Cluster count (10 random pulls)")

pdf("isoseq3_QC-plots.pdf", onefile = TRUE, width=12, height=8)
lay <- rbind(c(1,1,1,1,5,2,2,2),
             c(3,3,3,3,4,4,4,4))
table.legend <- "X% transcripts have Y or less supporting CCS's\n\n\n"
mytheme <- gridExtra::ttheme_default(
  core = list(fg_params=list(cex = 0.65)),
  colhead = list(fg_params=list(cex = 0.65)),
  rowhead = list(fg_params=list(cex = 0.65)))
grid.arrange(p1, 
             tableGrob(cum.data, 
                       rows=NULL, 
                       theme = mytheme), 
             p2, 
             p3,
             ncol=2,
             top=textGrob(title, gp=gpar(fontsize=20, font=3)),
             layout_matrix = lay,
             vp=viewport(width=0.95, height=0.95))
# add legend
grid.text(table.legend, 
          x=unit(0.8, "npc"), 
          y=unit(0.87, "npc"),
          gp=gpar(fontsize=11, font=3))
          
#          family="Times New Roman"))
null <- dev.off()
