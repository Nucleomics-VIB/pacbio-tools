#!/usr/bin/perl -w

use strict;
use warnings;  

# script: SamKeepReadNames.pl
# parse a SAM file and a list of polymerase names (excluding coordinates)
# save matching reads to a stdout
# REM: can be used to extract control reads from a subread file for downstream CCS analysis

my $usage = "Usage $0 <input.sam> <FOFN>\n";
my $infile = shift;
my $fofn = shift or die $usage;

open (LIST, $fofn) || die "cannot open file ".$fofn."!";
my @list;
my $count;

# store read names in array
while (my $id = <LIST>) {
	$count++;
	chomp($id);
	push(@list, $id);
	}
close LIST;

print STDERR "$count names found\n";

# parse and filter SAM
open BAM,"samtools view -h $infile | ";

while(<BAM>){
	## keep header lines (if you used -h in the samools command)
	if(/^(\@)/) {
		print STDOUT $_;
		next;
	}
	
	# parse one row
	my $name = (split(/\t+/))[0];
	#print STDOUT $name."\n";
	my $poly = $name =~ s/\/[^\/]*$//r;
	#print STDOUT $poly."\n";
	if ( grep( /^$poly$/, @list ) ) {
  		print STDOUT $_;
	}
}
