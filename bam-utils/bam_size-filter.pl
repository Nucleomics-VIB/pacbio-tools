#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use Getopt::Std;

# bam_size-filter.pl
# filter BAM read data for min and/or max read-length
# save filtered reads to new BAM file (optional)
# output filtered lengths to a text file for stats
#
# Stéphane Plaisance - VIB-NC-BITS Jan-31-2017 v1.1
#
# visit our Git: https://github.com/Nucleomics-VIB

# required:
# Samtools locally installed
print "samtools installed" if grep { -x "$_/samtools"}split /:/,$ENV{PATH};

############################
# handle command parameters
############################

# disable buffering to get output during long process (loop)
$|=1; 

getopts('i:m:x:bh');
our ( $opt_i, $opt_m, $opt_x, $opt_b, $opt_h );

my $usage = "Aim: Filter a BAM file by read length
#  print filtered read lengths to file
#  (also output kept reads to BAM if -b is set)
## Usage: bam_size-filter.pl <-i bam-file>
# optional <-m minsize>
# optional <-x maxsize>
# optional <-b to also create a BAM output (default only text file of lengths)>
# <-h to display this help>";

####################
# declare variables
####################

my $infile = $opt_i || die $usage . "\n";
my $minlen = $opt_m;
my $maxlen = $opt_x;
# at least one set
( defined($opt_m) || defined($opt_x) ) || die "# set min, max or both!\n".$usage."\n";
my $makebam;
defined($opt_b) && ( $makebam = 1 );
defined($opt_h) && die $usage . "\n";

my $minlabel = defined($minlen) ? "_gt".$minlen : "";
my $maxlabel = defined($maxlen) ? "_lt".$maxlen : "";
my $outname=basename($infile, ".bam").$minlabel.$maxlabel.".bam";
my $lenfile=basename($infile, ".bam").$minlabel.$maxlabel."_lengths.txt";

# create handler for data parsing
open BAM,"samtools view -h $infile |";
( $makebam == 1 ) && open OUTBAM,"| samtools view -bS -h - > $outname";
open LENDIST,"> $lenfile";

my $countgood=0;
my $countbad=0;
my $countshort=0;
my $countlong=0;

while(<BAM>){
	# header
	if (/^(\@)/) {
		defined($makebam) && print OUTBAM $_;
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

	# in range by default
	( $makebam == 1 ) && print OUTBAM $_ . "\n";
	print LENDIST $readlen . "\n";
	$countgood++;
}

print STDOUT "# kept $countgood reads\n";
print STDOUT "# filtered out $countbad reads\n";
print STDOUT "# reads shorter than min $countshort\n";
print STDOUT "# reads longer than max $countlong\n";

if ( $makebam == 1 ) {
	print STDOUT "# results are stored in $outname and $lenfile\n";
	} else {
	print STDOUT "# results are stored in $lenfile\n";
}
