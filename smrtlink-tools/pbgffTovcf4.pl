#!/usr/bin/perl
use strict;
use warnings;
use File::Basename;
use POSIX qw(strftime);

# script: pbgff2vcf4.pl
# convert PacBio GFF v3.0 file to VCF 4.2 
#
# Stephane Plaisance BITS-VIB, 2017-03-23 v1.0
my $version="1.0";

# requires samtools to fetch missing bases from the reference
grep { -x "$_/samtools"}split /:/,$ENV{PATH} || \
	die "#samtools not found in PATH and required!";

# requires awk to fetch contigs from the fasta faidx
grep { -x "$_/awk"}split /:/,$ENV{PATH} || \
	die "#awk not found in PATH and required!";

#### Important note: ####################################################################
# PacBio VCF calls have modified contig names lacking the '|arrow' (or other post-processing tag) present in the original data
# we therefore need a fasta file with matching headers
# to obtain such file, one can create a new version of the assembly using sed
# cat pb_assembly.fasta | sed -e 's/|.*$//g' > cleaned-pb_assembly.fasta
# followed by samtools faidx cleaned-pb_assembly.fasta
#########################################################################################

my $comment="# !!! this code is under development and may contain errors";
print $comment."\n";

@ARGV ge 2 or die ("usage: pbgff2vcf4.pl <pacbio_gff3.gff> <indexed-fasta-reference> <sample name (optional)\n");

my $infile = $ARGV[0];
my $reference = $ARGV[1];
my $smpln = defined($ARGV[2]) ? $ARGV[2] : "sample1";

my $refname=basename($reference);
my $outfile = basename($infile, ".gff");

# build contig lines for header (using code from https://www.biostars.org/p/198660/)
my $q=`awk '{printf("##contig=<ID=%s,length=%d>\\n",\$1,\$2);}' $reference.fai`;
my $contigs=$q || die "# problem fetching the list of contigs from $reference.fai!";
chomp($contigs);

open (IN, $infile) || die "Cannot open $infile\n";
# print to sdtout until stable version
# open (OUT, ">".$outfile."_v4.vcf") || die "Cannot write to ".$outfile."_v4.vcf\n";

my $datestring = strftime "%Y%m%d", localtime;

my $header = <<"EOT";
##fileformat=VCFv4.2
##fileDate=$datestring
##source=pbvcf2vcf4.pl (version:$version)
##comment=\"$comment\"
##source=\"$infile\"
##reference=$refname
$contigs
##INFO=<ID=NS,Number=1,Type=Integer,Description="Number of samples with data">
##INFO=<ID=DP,Number=1,Type=Integer,Description="Total read depth at the locus">
##INFO=<ID=AC,Number=2,Type=Integer,Description="Allele Count">
##INFO=<ID=ZY,Number=1,Type=String,Description="Variant Zygosity">
##INFO=<ID=VT,Number=1,Type=String,Description="Variant Type">
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tINFO\tFORMAT\t$smpln
EOT

print STDOUT $header;

# other lines are data
while(<IN>){
	next if /^#/; # omit header lines
	# data row
	chomp();
	# get all fields as defined in variant GFF format 2.1 specs
	my ( $seqid, $source, $type, $start, $end, $score, $strand, $phase, $attributes ) = split('\t', $_);
	chomp($attributes);

	# parse attributes and convert to hash
	my @aa = split(";", $attributes);
	my %h;
	%h = map { my ( $key, $value ) = split "="; ( $key, $value ) } @aa;
    #print "$_ $h{$_}\n" for (keys %h);

	my ($ref, $alt, $info, $ac, $format, $gt, $zyg) = ();
	
	# default content
	$info = "NS=1;DP=".$h{coverage};
	# add allele count if present
	if (defined($h{frequency})) {
		( $ac = $h{frequency} ) =~ s/\//,/;
		$info .= ";AC=".$ac;
	}

	# parse variantSeq to identify ploidy and zygosity
	if ($h{variantSeq} =~ m/\//) {
		# two alleles
		my ($gt1, $gt2) = split("/", $h{variantSeq});
		$zyg = ( $gt1 eq $gt2 ) ? "hom" : "het";
		$gt1 =~ s/[ACGTN]+/1/;
		$gt2 =~ s/[ACGTN]+/1/;
		$gt1 =~ s/\./0/;
		$gt2 =~ s/\./0/;
		# correct if different alleles and both non-ref
		if (($zyg eq "het") && ($gt1 eq $gt2)) {
			$gt2=2;
		}
		$gt = $gt1."/".$gt2;
	} else {
		# one allele only
		$zyg = "hap";
		$gt = "1";
	}
	
	$info .= ";ZY=".$zyg;
		
	# only one field for FORMAT so far
	$format = "GT";
		
	############### INSERTIONS ###########
	if ($type eq "insertion") {
		# '.' should be replaced by the base at $start
		# handle missing base in INS calls
		if ($start > 0) {
			# fetch reference base for that position
			my @q = `samtools faidx $reference \"$seqid:$start-$start\"`;
			$ref=$q[1] || die "# problem fetching the reference base at $seqid:$start!";
			chomp($ref);
			$h{reference}=$ref;
		} else {
			# handle exception when insertion is before 1st base (telomere)		
			$h{reference}="N";
		}
		# TODO, add the ref base before the call
		my @alt = split("/", $h{variantSeq});
		my @cor = map {$h{reference}.$_} @alt;
		$h{variantSeq} = join("/", @cor);
		$h{variantSeq} =~ s/\.//g;
	}
	
	############### DELETIONS ###########
	if ($type eq "deletion") {
		
	}

	########### SUBSTITUTIONS ###########
	if ($type eq "substitution") {
		
	}

	# add type to INFO for filtering purpose
	$info .= ";VT=".$type;

	############### OUTPUT ##############
	# print vcf call in format 4.x
	print STDOUT join("\t", $seqid, $start, $source, $h{reference}, $h{variantSeq}, $h{confidence}, "PASS", $info, $format, $gt)."\n";
}

# close OUT

exit 0;
