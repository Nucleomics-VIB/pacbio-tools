#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Getopt::Std;

# bam_size-filter.pl
# filter BAM read data for min and/or max read-length
# save filtered records to new BAM file (optional)
# save filtered records to new FASTA file (optional)
# output filtered lengths to a text file for stats
#
# Stéphane Plaisance - VIB-NC-BITS Jan-31-2017 v1.1
# v1.2 adding FASTA output option
# v1.3 adding FASTQ output (although Sequel Qscores are all arbitrarily set to '!')
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools locally installed
if (! grep { -x "$_/samtools"}split /:/,$ENV{PATH}) {
	print "samtools is not installed or not in PATH";
	exit 1;
	}

############################
# handle command parameters
############################

# disable buffering to get output during long process (loop)
$|=1; 

my $version="1.3";

# cmd arguments
getopts('i:m:x:bfqh');
our ( $opt_i, $opt_m, $opt_x, $opt_b, $opt_f, $opt_q, $opt_h );
our ( $makebam, $makefasta, $makefastq ) = ( 0, 0, 0 );

my $usage = "Aim: Filter a BAM file by read length
#  print filtered read lengths to file
#  (also output filtered reads to BAM if -b is set)
#  (also output filtered reads to FASTA if -f is set)
#  (also output filtered reads to FASTQ if -q is set)
## Usage: bam_size-filter.pl <-i bam-file>
# optional <-m minsize>
# optional <-x maxsize>
# optional <-b to also create a BAM output (default only text file of lengths)>
# optional <-f to also create a FASTA output (default only text file of lengths)>
# optional <-q to also create a FASTA output (default only text file of lengths)>
# <-h to display this help>
# script version: ".$version;

####################
# declare variables
####################

my $infile = $opt_i || die $usage . "\n";
my $minlen = $opt_m;
my $maxlen = $opt_x;
# at least one set
( defined($opt_m) || defined($opt_x) ) || die "# set min, max or both!\n".$usage."\n";
defined($opt_b) && ( $makebam = 1 );
defined($opt_f) && ( $makefasta = 1 );
defined($opt_q) && ( $makefastq = 1 );
defined($opt_h) && die $usage . "\n";

# variables
my $minlabel = defined($minlen) ? "_gt".$minlen : "_gt_na";
my $maxlabel = defined($maxlen) ? "_lt".$maxlen : "_lt_na";
my $outbname=basename($infile, ".bam").$minlabel.$maxlabel.".bam";
my $outfname=basename($infile, ".bam").$minlabel.$maxlabel.".fasta";
my $outqname=basename($infile, ".bam").$minlabel.$maxlabel.".fastq";
my $lenfile=basename($infile, ".bam").$minlabel.$maxlabel."_lengths.txt";

# create handlers for data parsing
open BAM,"samtools view -h $infile |";
# create handlers for data writing
open LENDIST, "> $lenfile";
( $makebam == 1 ) && open OUTBAM, " | samtools view -hSb - > $outbname";
( $makefasta == 1 ) && open OUTFASTA, "> $outfname";
( $makefastq == 1 ) && open OUTFASTQ, "> $outqname";

# counters
my $countgood=0;
my $countshort=0;
my $countlong=0;

# parse data and process
while(<BAM>){
	# header
	if (/^(\@)/) {
		( $makebam == 1 ) && print OUTBAM $_;
		next;
		}
	
	my @fields=split("\t", $_);
	my $readlen=length($fields[9]);

	# filter short
	if ( defined($minlen) ) {
		if ( $readlen < $minlen ) {
			$countshort++;
			next;
			}
		}

	# filter long
	if ( defined($maxlen) ) {
		if ( $readlen > $maxlen ) {
			$countlong++;
			next;
			}
		}

	# otherwise in range by default
	$countgood++;
	print LENDIST $readlen . "\n";
	# optional
	( $makebam == 1 ) && print OUTBAM $_;
	( $makefasta == 1 ) && print OUTFASTA ">".$fields[0]."\n".$fields[9]."\n";
	( $makefastq == 1 ) && print OUTFASTQ "@".$fields[0]."\n".$fields[9]."\n+\n".$fields[10]."\n";
}

# report counts
print STDOUT "# kept $countgood reads\n";
print STDOUT "# ignored $countshort reads shorter than $minlen \n";
print STDOUT "# ignored $countlong reads longer than $maxlen \n";
print STDOUT "# Lengths are stored in $lenfile\n";
# optional
( $makebam == 1 ) && print STDERR "# BAM results are stored in $outbname\n";
( $makefasta == 1 ) && print STDERR "# FASTA results are stored in $outfname\n";
( $makefastq == 1 ) && print STDERR "# FASTQ results are stored in $outqname\n";
