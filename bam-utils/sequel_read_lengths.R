#!/usr/bin/RScript

# Analysze PacBio Sequel BAM data (subreads and scraps)
# collect sequence lengths and make plots
# usage: sequel_read_lengths.R <path to the data>
#
# Stephane Plaisance VIB-NC March-15-2018 v1.0

# R libraries
suppressPackageStartupMessages(library("grid"))
suppressPackageStartupMessages(library("gridExtra"))
suppressPackageStartupMessages(library("readr"))

args <- commandArgs(trailingOnly=TRUE)

# test if there is at least one argument: if not, return an error
if (length(args)==0) {
  stop("At least one argument must be supplied (input path).\n", call.=FALSE)
} else if (length(args)==1) {
  userpath <- args[1]
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
  result=c(count=length(x),mean=mean(x),median=median(x), N50=N50, L50=L50)
  # return list
  result
}

# read data in
scraps <- list.files(path=userpath, pattern = "scraps.bam$")
subreads <- list.files(path=userpath, pattern = "subreads.bam$")

# optionally, process polymerase reads rebuilt using pb2polymerase.sh
polymerase <- list.files(path=userpath, pattern = ".zmws_length-dist.txt$")
  
# test if found
if (!exists("scraps")){
  sink("stderr.txt")
  cat("ERROR: The scaps BAM file is not found at his path\n")
  quit(save="no",status=1,runLast=FALSE)
}

if (!exists("subreads")){
  sink("stderr.txt")
  cat("ERROR: The subreads BAM file is not found at his path\n")
  quit(save="no",status=1,runLast=FALSE)
}

# get read lengths from two bam files
cat(paste0("# reading subreads from: ",userpath, "/" ,subreads),"\n")
sub <- as.numeric(system(paste0("/opt/biotools/samtools/bin/samtools view ", 
	userpath, "/", subreads, " | /usr/bin/awk '{print length($10)}'"), intern = TRUE))

write.table(sub, file="subread_lengths.txt", row.names = FALSE, col.names = FALSE)

cat(paste0("# reading scraps from: ",userpath, "/" ,scraps),"\n")
scr <- as.numeric(system(paste0("/opt/biotools/samtools/bin/samtools view ", 
	userpath, "/", scraps, " | /usr/bin/awk '{print length($10)}'"), intern = TRUE))

write.table(scr, file="scap_lengths.txt", row.names = FALSE, col.names = FALSE)

# compute and plot
# analyze scraps

layout(
  matrix(
    c(1,1,2,3,3,4,5,5,6,7,7,8), 
    nc=3, byrow = TRUE
  )
)
#layout.show(6)

pdf(file="Sequel_read-lengths.pdf", width=10, height=6, onefile=TRUE)
par(mar=c(2,2,1,1))

# all scraps reads
hist(scr, breaks=500, xlim=c(0,50000), main="Scraps read lengths")
stats <- floor(lenstats(scr))
abline(v=stats['N50'], col='blue')
plot.new()
grid.table(as.data.frame(stats))

# scraps subset > 1kb
gt500k <- scr[scr>1000]
hist(gt500k, breaks=500, xlim=c(0,50000), main="Scraps read lengths (>1k)")
stats2 <- floor(lenstats(gt500k))
abline(v=stats2['N50'], col='blue')
plot.new()
grid.table(as.data.frame(stats2))

# subreads
hist(sub, breaks=100, xlim=c(0,50000), main="Subread lengths")
stats3 <- floor(lenstats(sub))
abline(v=stats3['N50'], col='blue')
plot.new()
grid.table(as.data.frame(stats3))

# polymerase reads if produced and present as *.zmws_length-dist.txt
if (exists("polymerase")){
  cat(paste0("# reading polymerase reads from: ", polymerase,"\n"))
  polymerase <- read_csv(polymerase)
  hist(polymerase$len, breaks=50000, xlim=c(0,50000), main="Polymerase read lengths")
  stats4 <- floor(lenstats(polymerase$len))
  abline(v=stats4['N50'], col='blue')
  plot.new()
  grid.table(as.data.frame(stats4))
}

close <- dev.off()
# end