#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Getopt::Std;

# bam_size-filter.pl
# reconstitute polymerase reads from subreads.bam and scraps.bam
# filter BAM polymerase read data for min and max polymerase read-size 
#
# Stéphane Plaisance - VIB-NC-BITS Jan-18-2017 v1.0
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools locally installed

############################
# handle command parameters
############################

# disable buffering to get output during long process (loop)
$|=1; 

getopts('i:m:bh');
our ( $opt_i, $opt_m, $opt_b, $opt_h );

my $usage = "Aim: Filter a BAM file by read length
  keep only reads <= <max> size (-m) [keep all if m=-1]
  print their length to file
  (also output subset BAM if -b is set)
## Usage: bam_size-filter.pl <-i bam-file> <-m limit>
# if m = -1, the whole BAM will be kept
# optional <-b to also create a BAM output (default only text file of lengths)>
# <-h to display this help>";

####################
# declare variables
####################

my $infile = $opt_i || die $usage . "\n";
my $max = $opt_m || die $usage . "\n";
my $makebam;
defined($opt_b) || undef($makebam);
defined($opt_h) && die $usage . "\n";

my $label=$max>0 ? "_lt".$max : "_all";
my $outname=basename($infile, ".bam").$label.".bam";
my $lenfile=basename($infile, ".bam").$label."_lengths.txt";

# create handler for data parsing
open BAM,"samtools view -h $infile |";
defined($makebam) && open OUTBAM,"| samtools view -bS -h - > $outname";
open LENDIST,"> $lenfile";

my $countgood=0;
my $countbad=0;

while(<BAM>){

if (/^(\@)/) {
	defined($makebam) && print OUTBAM $_;
	next;
	}
	
my @fields=split("\t", $_);
my $readlen=length($fields[9]);

# filter by length or no filter is -1
if ( $readlen <= $max || $max==-1 ) {
	defined($makebam) && print OUTBAM $_ . "\n";
	print LENDIST $readlen . "\n";
	$countgood++;
	} else {
	$countbad++;
	}
# end BAM data
}

print STDOUT "# kept $countgood reads\n";
print STDOUT "# filtered out $countbad reads\n";
if ( defined($makebam) ){
	print STDOUT "# results are stored in $outname and $lenfile\n";
	} else {
	print STDOUT "# results are stored in $lenfile\n";
}