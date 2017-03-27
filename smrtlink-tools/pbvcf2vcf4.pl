#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use POSIX qw(strftime);

# script: pbvcf2vcf4.pl
# convert PacBio VCF v3.3 file to VCF 4.2 
# currently only for haploid data
#
# Stephane Plaisance BITS-VIB, 2017-03-23 v1.0

# requires samtools
grep { -x "$_/samtools"}split /:/,$ENV{PATH} || \
	die "#samtools not found in PATH and required!";

# requires awk to fetch contigs from the fasta faidx
grep { -x "$_/awk"}split /:/,$ENV{PATH} || \
	die "#awk not found in PATH and required!";

#### Important note: ####################################################################
# PacBio VCF calls have modified contig names lacking the '|arrow' (or other method) part
# requires a fasta file with header lacking '|arrow' or similar
# to clean these, create a new version of the assembly using sed
# cat pb_assembly.fasta | sed -e 's/|arrow//g' > cleaned-pb_assembly.fasta
# followed by samtools faidx cleaned-pb_assembly.fasta
#########################################################################################

my $version="1.1";
my $comment="# !!! this code is currently only valid for haploid calls";
print $comment."\n";

@ARGV == 2 or die ("usage: pbvcf2vcf4.pl <pacbio_vcf3.3.vcf> <indexed-fasta-reference>\n");

my $infile = $ARGV[0];
my $reference = $ARGV[1];
my $refname=basename($reference);
my $outfile = basename($infile, ".vcf");

# build contig lines for header (using code from https://www.biostars.org/p/198660/)
my $q=`awk '{printf("##contig=<ID=%s,length=%d>\\n",\$1,\$2);}' $reference.fai`;
my $contigs=$q || die "# problem fetching the list of contigs from $reference.fai!";
chomp($contigs);

open (IN, $infile) || die "Cannot open $infile\n";
open (OUT, ">".$outfile."_v4.vcf") || die "Cannot write to ".$outfile."_v4.vcf\n";

my $datestring = strftime "%Y%m%d", localtime;

my $header = <<"EOT";
##fileformat=VCFv4.2
##fileDate=$datestring
##source=pbvcf2vcf4.pl (version:$version)
##comment=\"$comment\"
##reference=$refname
$contigs
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of samples with data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total read depth at the locus">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t$outfile
EOT

print OUT $header;

# other lines are data
while(<IN>){
	next if /^#/; # omit header lines
	# data row
	chomp();
	my @fields=split('\t', $_);
	my ($chr, $start, $ID, $ref, $alt, $qual, $filter, $info) = @fields[ 0..7 ];
	chomp($info);
	# remove D and I from Alt and fetch Ref for insertions
	## deletion call
	$alt =~ s/^D[0-9]+//g;

	# replace 0 by PASS for info
	$filter = $filter eq "0" ? "PASS" : $filter;
	
	## insertion call, fetch the base before the insertion
	if ($alt =~ /^I/) {
		if ($start>0) {
			# fetch reference base for that position
			my @q = `samtools faidx $reference \"$chr:$start-$start\"`;
			$ref=$q[1] || die "# problem fetching the reference base at $chr:$start!";
			chomp($ref);
			$alt =~ s/^I//g;
			} else {
			# handle exception when insertion is before 1st base (telomere)		
			$ref = "N";
			$alt =~ s/^I//g;
		}
	}
	$alt = length($alt)>0 ? $alt : ".";
	# print vcf call
	print OUT join("\t", $chr, $start, $ID, $ref, $alt, $qual, $filter, $info, "GT",'1/1')."\n";
}
