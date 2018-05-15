#!/usr/bin/perl -w
use strict;
use warnings;  

# autoflush
$|=1;

# filtermappings.pl <inbam> <query>
# read sam or bam
# check for proper sorting or die
# filter out secondary mappings with -F 256
# filter by user query chr22 or chr22:start-end
# print header and matching pairs to STDOUT
#
# Stephane Plaisance (VIB-NC) 2018/05/09; v1.0
# visit our Git: https://github.com/Nucleomics-VIB

my $infile = $ARGV[0] || die "# please provide an input BAM file sorted in queryname order";
my $query = $ARGV[1] || die "# please provide a query like chr2 of chr2:100-200";

# decompose filter query
my ($qchr, $qcoords) = split(":", $query);
$qchr || die "# the query should be like chr2 of chr2:100-200";
my ($qstart, $qend) = $qcoords ? split("-", $qcoords) : ( undef, undef );

# echo query (debug)
# print STDERR $qchr."_".($qstart ? $qstart : ".")."_".($qend ? $qend : ".")."\n";

# open a connection using a piped samtools command
my $DATA = OpenSAMBAM($infile) or die $!;
my $fcount = 0;

# test for correct sorting order
my $firstline=<$DATA>;
$firstline =~ /\@HD\tVN:.*\tSO:queryname/ || die "## queryname sorted sam/bam input is required";
print STDOUT $firstline;

# parse remaining of the input
while ( my $line = <$DATA> ) {
	# pass header lines to STDOUT as is
	if ($line =~ /^\@/) {
		print STDOUT $line;
		next;
	}
	
	# split $line
	my ($rname1, $chr1, $start1) = (split("\t", $line))[0,2,3];

	# test next line for readname match
	my $pos = tell();
	my $nextline = <$DATA>;

	# split $nextline
	my ($rname2, $chr2, $start2) = (split("\t", $nextline))[0,2,3];

	# test if readnames match
	if ( $rname2 ne $rname1 ) {
		# not a pair, drop read1
		seek $DATA, $pos, 0;
		next;
	}

	# test first in pair is in range
	if ($chr1 eq $qchr) {
		if ( $qstart ) {
			if ( $start1 ge $qstart && $start1 le $qend ) {
				print STDOUT $line, $nextline;
				$fcount++;
				next;
			}
		} else {
			print STDOUT $line, $nextline;
			$fcount++;
			next;
		}
	}
	
	# test second in pair
	if ($chr2 eq $qchr) {
		if ( $qstart ) {
			if ( $start2 ge $qstart && $start2 le $qend ) {
				print STDOUT $line, $nextline;
				$fcount++;
			}
		} else {
			print STDOUT $line, $nextline;
			$fcount++;
		}
	}
}

# report count
print STDERR "# ".$fcount." pairs kept";

#### Subs ####
sub OpenSAMBAM {
    my $infile = shift;
    my $FH;
    if ($infile =~ /.sam$|.bam$/i) {
	open( $FH, "samtools view -h -F 256 $infile | " );
    } else {
	die ("$!: do not recognise file type $infile");
	# if this happens add, the file type with correct opening proc
    }
    return $FH;
}
