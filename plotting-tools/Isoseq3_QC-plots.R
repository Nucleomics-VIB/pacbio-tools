#!/usr/bin/env Rscript

# script: Isoseq3_QC-plots.R
# create plots from Isoseq3 polished.cluster_report.csv
# designed for single smartcell data !
# SP & Joke A. 2019-05-24 v3

# required libraries
suppressMessages(library("readr"))
suppressMessages(library("dplyr"))
suppressMessages(library("stringr"))
suppressMessages(library("ggplot2"))
suppressMessages(library("scales"))
suppressMessages(library("grid"))
suppressMessages(library("gridExtra"))
suppressMessages(library("data.table"))

args <- commandArgs(trailingOnly=TRUE)
# argument for plot title

if (length(args)==0) {
  title="Isoseq3 QC plots"
} else if (length(args)==1) {
  title <- args[1]
}

####################################################################################
# load polished.cluster_report.csv
####################################################################################

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
  dat <- suppressWarnings(hist.data[min(which(hist.data$percent>lim)),])
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

# 10x subset 0 to 100% & count unique Transcripts
# remove transcripts with only one row & count unique Transcripts
plot.data <- data.frame(CCS_sample=numeric(), Transcript_count=numeric(), min=factor())

for (iter in seq(1, 10, by=1)) {
for (i in seq(0, 1, by=0.1)) {
  # sample and count
  dat <- sample_frac(polished_cluster_report, i)
  plot.data <- rbind(plot.data, c( i, length(unique(dat$cluster_id)), 0) )
  # group and add counts
  dat <- dat %>%
    group_by(cluster_id) %>%
    summarise(n = n()) 
  # filter at FLNC=1 and count
  res <- dat %>%
    filter(n == 1)
  plot.data <- rbind(plot.data, c( i, length(unique(res$cluster_id)), 1) )
  # filter at FLNC>1 and count
  res <- dat %>%
    filter(n > 1)
  plot.data <- rbind(plot.data, c( i, length(unique(res$cluster_id)), 2) )
  # filter at FLNC>2 and count
  res <- dat %>%
    filter(n > 2)
  plot.data <- rbind(plot.data, c( i, length(unique(res$cluster_id)), 3) )
  }
}

# merge the two dataframes and plot
colnames(plot.data) <- c("CCS_sample", "Transcript_count", "min")

p2 <- suppressMessages(ggplot(plot.data, aes(x=CCS_sample, y=Transcript_count, group=min, shape==factor(min), colour=factor(min))) +
  geom_smooth(method="loess", se=FALSE, fullrange=TRUE, size=1) +
  geom_point(size=3) +
  scale_shape_identity() +
  scale_x_continuous(labels = scales::percent) +
  theme_classic() +
  theme(axis.text.x=element_text(size=rel(1)),
        axis.text.y=element_text(size=rel(1)),
        text = element_text(size=12)) +
  xlab("CCS sample from polished.cluster_report.csv") +
  ylab("Transcript count (10 random pulls)") +
  scale_color_manual(labels = c("one or more", "exactly 1", "more than 1", "more than 2"), 
                       values = hue_pal()(4)) +
  guides(color=guide_legend("CCS count \n/Transcript"))
)

pdf("isoseq3_QC-plots.pdf", onefile = TRUE, width=12, height=8)
lay <- rbind(c(1,1,1,1,4,2,2,2),
             c(3,3,3,3,3,4,4,4))
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
