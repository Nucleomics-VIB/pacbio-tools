#!/usr/bin/perl -w

use strict;
use warnings;  

# autoflush
$|=1;

# script: SamKeepReadNames.pl
# parse a SAM file and a text file with a list of read names (first field of a SAM record)
# print matching rows to stdout
#
# requires samtools to parse SAM/BAM
#
# Stéphane Plaisance - VIB-NC 2018_08_03, v1.01
#
# visit our Git: https://github.com/Nucleomics-VIB

my $usage = "Usage $0 <SAM/BAM> <list_of_read-names.txt>\n";
my $infile = shift;
my $lorn = shift or die $usage;

# store read names in array
open (LIST, $lorn) || die "cannot open file ".$lorn."!";
my @list;
my $count;
my $match;

# load list in RAM
while (my $id = <LIST>) {
	$count++;
	chomp($id);
	push(@list, $id);
	}
close LIST;

# keep unique records only
my @unique = do { my %seen; grep { !$seen{$_}++ } @list };

print STDERR scalar(@unique)." unique read names loaded\n";

# parse and filter SAM
open (BAM, "samtools view -F 256 -h $infile | ") || die "cannot open file ".$infile." with samtools!";

while(<BAM>){
	## keep header lines as we used -h in the samtools command
	if(/^(\@)/) {
		print STDOUT $_;
		next;
	}
	
	# parse one row
	my $name = (split(/\t+/))[0];

	if ( grep( /^$name$/, @unique ) ) {
  		print STDOUT $_;
  		$match++;
  		$match =~ /100$/ && print STDERR "+";
	}
}
