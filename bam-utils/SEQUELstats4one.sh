#!/bin/bash

# run various stats with SEQUELstats on subreads and scraps BAM as done at Welcome Sanger
# usage: SEQUELstats4one.sh <path to the Sequel BAM data>
#
# Stephane Plaisance VIB-NC March-15-2018 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# requirements:
# https://github.com/VertebrateResequencing/SEQUELstats/issues/1#issuecomment-373371848
# we work in a user writable folder
# scraps.fof in the current folder with the full path to the scraps.bam data
# subreads.fof in the current folder with the full path to the subreads.bam data
# $SEQUEL_STATS_path and other custom variables are defined as detailed in the README.md
# all dependencies are present

BASE=$(pwd)

# get sequel run-folder name from the scraps.fof
RUNNAME=$(cat scraps.fof)
RUNNAME=$(basename $RUNNAME)
RUNNAME=${RUNNAME%.scraps.bam}

# compute steps (check each succeeds before going on, STEP1 is the lengthiest as it parses the two BAMs
$SEQUEL_STATS_path/SEQUEL_pipe.sh subreads.fof scraps.fof $BASE 1 STEP_01
$SEQUEL_STATS_path/SEQUEL_pipe.sh subreads.fof scraps.fof $BASE 1 STEP_02
$SEQUEL_STATS_path/SEQUEL_pipe.sh subreads.fof scraps.fof $BASE 1 STEP_03
$SEQUEL_STATS_path/SEQUEL_pipe.sh subreads.fof scraps.fof $BASE 1 STEP_04

# the results should be in $BASE/${RUNNAME}/stats by now as 
# stats
#├── [4.0K]  Hn
#│   └── [ ]  ${RUNNAME}.Hn.stats
#├── [4.0K]  HpSn
#│   └── [ ]  ${RUNNAME}.HpSn.stats
#└── [4.0K]  HpSp
#    ├── [ ]  ${RUNNAME}.HpSp.aCnt
#    ├── [ ]  ${RUNNAME}.HpSp.hist
#    ├── [ ]  ${RUNNAME}.HpSp.lFlg
#    └── [ ]  ${RUNNAME}.HpSp.stats

# plot from resulting stats
Rscript $SEQUEL_STATS_path/SEQUEL_plot.R $BASE/${RUNNAME}/stats ${RUNNAME}_stats

# will create in stats:
# ${RUNNAME}_stats.estimated_lib_size_distribution.full_data.png
# ${RUNNAME}_stats.estimated_lib_size_distribution.png
# ${RUNNAME}_stats.Polymerase_and_subread.length_profiles.png
# ${RUNNAME}_stats.seq_run.yield_and_efficiency.png
# ${RUNNAME}_stats.SMRT_cell.efficiency.png
# ${RUNNAME}_stats.SMRT_cell.processed_output.png
# ${RUNNAME}_stats.SMRT_cell.raw_output.png

# done