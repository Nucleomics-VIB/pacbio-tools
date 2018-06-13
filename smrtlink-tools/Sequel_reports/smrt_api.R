library("jsonlite")
library("XML")

smrt.url <- "http://gbw-s-pacbio01.luna.kuleuven.be:9091"
smrt.surl <- "https://gbw-s-pacbio01.luna.kuleuven.be:8243/SMRTLink/1.0.0"

readinteger <- function()
{
  n <- readline(prompt="Enter your choice: ")
  n <- as.integer(n)
  if (is.na(n)){
    n <- readinteger()
  }
  cat(paste0("# you selected: ",n))
  return(n)
}

get.run.info <- function() {
  cmd <- "/smrt-link/runs"
  url <- paste0(smrt.url, cmd, sep="")
  dat <- as.data.frame(t(fromJSON(url)))
  dat
}

get.run.list <- function() {
  runs <- get.run.info()
  runs.uid <- t(runs[c('name','uniqueId'),])
  runs.uid
  }

get.run.setup <- function(rid=rid) {
  cmd <- "/smrt-link/runs"
  url <- paste0(smrt.url, cmd, "/", rid, sep="")
  dat <- as.data.frame(t(fromJSON(url)))
  t(dat)
}

get.run.datamodel <- function(rid=rid) {
  cmd <- paste0("/smrt-link/runs/",  rid, "/datamodel", sep="") 
  url <- paste0(smrt.url, cmd, sep="")
  cat(url)
  dat <- xmlTreeParse(url)
  dat
}

get.sample.info <- function(rid=rid) {
  cmd <- paste0("/smrt-link/runs/", rid, "/collections", sep="")
  url <- paste0(smrt.url, cmd, sep="")
  dat <- as.data.frame(t(fromJSON(url)))
  dat
}


get.sample.list <- function(rid=rid) {
  sample <- get.sample.info(rid)
  sample.uid <- t(sample[c('name','context','runId','uniqueId'),])
  sample.uid
}

get.sample.setup <- function(sid=sid) {
  cmd <- paste0("/smrt-link/samples/", sid, sep="")
  url <- paste0(smrt.url, cmd, sep="")
  dat <- as.data.frame(t(fromJSON(url)))
  dat
}

get.sample.report.info <- function(sid=sid) {
  cmd <- paste0("/secondary-analysis/datasets/subreads/", sid, "/reports", sep="")
  url <- paste0(smrt.url, cmd, sep="")
  cat(url)
  dat <- as.data.frame(fromJSON(url))
  t(dat$dataStoreFile)
}

get.sample.report.list <- function(sid=sid) {
  reports <- get.sample.report.info(sid)
  report.uid <- reports[c('name','uuid'),]
  report.uid
}

get.qc.report <- function(repid=repid) {
  cmd <- paste0("/secondary-analysis/datastore-files/", repid, "/download", sep="")
  url <- paste0(smrt.surl, cmd, sep="")
  cat(url)
  dat <- fromJSON(url)
  dat
}

# full run info
all.runs <- get.run.info()
View(all.runs)

# list runs
runs <- get.run.list()
View(runs)

# get run uid from user
get.run.list()
user.choice <- readinteger()
runs[user.choice,]
rid <- runs[user.choice,'uniqueId']

# get run setup from rid
get.run.setup(rid)
run.setup <- get.run.setup("2d03009c-5da2-4016-bea7-2bb34da6ea68")

# get datamodel XML object
datamodel <- get.run.datamodel(rid)

# show full info for samples in selected run
sample.info <- get.sample.info(rid)

# list samples to pick a sample UID
samples <- get.sample.list(rid)

# get sample uid from user
get.sample.list(rid)
user.choice <- readinteger()
sid <- as.character(samples[user.choice,'uniqueId'])

# get sample setup for sid
get.sample.setup(sid)

# get sample report list
reports <- get.sample.report.info(sid)
View(reports)

# get sample report uid from user
View(get.sample.report.list(sid))
user.choice <- readinteger()
repid <- reports['uuid',user.choice]

# import report data (several level jason object)
rep <- get.qc.report(repid)
