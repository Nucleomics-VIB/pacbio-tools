#!/usr/bin/env python3
"""countfasta.py - FASTA length distribution and assembly summary statistics.

Reports a length histogram, total residues, sequence count, N25/N50/N75 with the
number of sequences at or above each threshold, and GC content, aggregated over
one or more FASTA files (plain or gzipped, or '-' for stdin).

Independent implementation
--------------------------
This is an original VIB Nucleomics Core implementation, written from a
behavioural specification (CLI contract + reported values) and NOT derived from,
translated from, or based on any pre-existing script. It replaces the removed
third-party 'countFasta.pl' (UC Davis Genome Center, no licence grant), which
was not consulted while writing this file. See NOTICE.md and issue #2.

Memory
------
Sequence residues are never held in memory: each line is consumed and discarded.
Only a histogram of exact sequence lengths is retained, so footprint is O(number
of distinct lengths), not O(total residues). N25/N50/N75 are therefore exact
even on large assemblies.

Created by Stephane Plaisance - VIB Nucleomics Core
script version 1.0.0, 2026_08_28

visit our Git: https://github.com/Nucleomics-VIB
"""

import argparse
import gzip
import json
import sys
from collections import Counter

__version__ = "1.0.0"
__author__ = "Stephane Plaisance - VIB Nucleomics Core"

DEFAULT_BIN_SIZE = 100

# Residue byte tables, both cases. Anything not matched lands in 'other'.
_GC = (b"G", b"g", b"C", b"c")
_AT = (b"A", b"a", b"T", b"t")
_N = (b"N", b"n")
_WHITESPACE = (b"\n", b"\r", b" ", b"\t")
_HEADER = 0x3E          # '>'
_NEWLINE_HEADER = b"\n>"
_COMMENT = 0x3B         # ';' legacy FASTA comment line
_NEWLINE_COMMENT = b"\n;"
_BLOCK_SIZE = 1 << 22   # 4 MiB


class FastaStats:
    """Streaming accumulator for FASTA composition and length statistics."""

    def __init__(self):
        self.lengths = Counter()   # exact sequence length -> number of records
        self.total_length = 0
        self.n_records = 0
        self.empty_records = 0
        self.gc_count = 0
        self.n_count = 0
        self.acgt_count = 0
        self.current_length = 0   # residues of the record being read

    # -- accumulation ----------------------------------------------------

    def add_record(self, length):
        self.n_records += 1
        self.total_length += length
        if length == 0:
            self.empty_records += 1
        else:
            self.lengths[length] += 1

    def close_record(self):
        """Commit the record currently being read, if any. Returns 1 if committed."""
        self.add_record(self.current_length)
        self.current_length = 0
        return 1

    def add_residues(self, chunk):
        """Tally composition of a raw block of sequence bytes.

        `chunk` may span many sequence lines of one record and may contain the
        line breaks and padding whitespace between them; those are discounted
        from the length and never counted as residues. Counting a whole block at
        once keeps the work inside C-level bytes.count() instead of a per-line
        Python loop, which is what makes this usable on multi-gigabyte inputs.
        """
        whitespace = sum(chunk.count(ws) for ws in _WHITESPACE)
        self.current_length += len(chunk) - whitespace
        gc = sum(chunk.count(base) for base in _GC)
        self.gc_count += gc
        self.n_count += sum(chunk.count(base) for base in _N)
        self.acgt_count += gc + sum(chunk.count(base) for base in _AT)

    # -- derived values --------------------------------------------------

    @property
    def other_count(self):
        """Residues that are neither A/C/G/T nor N (IUPAC ambiguity, gaps, ...)."""
        return self.total_length - self.acgt_count - self.n_count

    @property
    def gc_percent(self):
        if self.total_length == 0:
            return 0.0
        return 100.0 * self.gc_count / self.total_length

    @property
    def n_percent(self):
        if self.total_length == 0:
            return 0.0
        return 100.0 * self.n_count / self.total_length

    @property
    def min_length(self):
        return min(self.lengths) if self.lengths else 0

    @property
    def max_length(self):
        return max(self.lengths) if self.lengths else 0

    @property
    def mean_length(self):
        if self.n_records == 0:
            return 0.0
        return self.total_length / self.n_records

    def nx(self, fraction):
        """Return (threshold_length, n_sequences_at_or_above) for the given fraction.

        The threshold is the length at which the cumulative sum of sequence
        lengths, taken longest-first, first reaches `fraction` of the total.
        The reported count is every sequence at or above that length, so all
        members of a tied length group are included.
        """
        if self.total_length == 0:
            return None
        target = self.total_length * fraction
        cumulative = 0
        n_seqs = 0
        for length in sorted(self.lengths, reverse=True):
            cumulative += length * self.lengths[length]
            n_seqs += self.lengths[length]
            if cumulative >= target:
                return length, n_seqs
        # Only reachable through floating-point drift on the final group.
        return self.min_length, self.n_records - self.empty_records

    def histogram(self, bin_size, sparse=False):
        """Return [(start, end, count)] bins of `bin_size` residues.

        Bins are 1-based and inclusive: with bin_size 100, a length of 100 falls
        in 1:100 and a length of 101 in 101:200. Zero-length records are excluded
        (they are reported separately). By default every bin between the lowest
        and highest occupied bin is emitted, including empty ones, so the shape
        of the distribution is readable; `sparse` emits occupied bins only.
        """
        if not self.lengths:
            return []
        binned = Counter((length - 1) // bin_size for length in self.lengths.elements())
        if sparse:
            indices = sorted(binned)
        else:
            indices = range(min(binned), max(binned) + 1)
        return [
            (idx * bin_size + 1, (idx + 1) * bin_size, binned.get(idx, 0))
            for idx in indices
        ]


def open_fasta(path):
    """Open a FASTA path as binary, transparently handling gzip and '-' for stdin."""
    if path == "-":
        return sys.stdin.buffer
    with open(path, "rb") as probe:
        magic = probe.read(2)
    if magic == b"\x1f\x8b":
        return gzip.open(path, "rb")
    return open(path, "rb")


def _next_line_marker(block, pos, has_comment):
    """Index of the newline before the next header or comment line, or -1.

    `has_comment` is tested once per block, not once per record: a legacy ';'
    comment line is essentially extinct, and searching for one unconditionally
    costs a full scan of the rest of the block for every record.
    """
    header = block.find(_NEWLINE_HEADER, pos)
    if not has_comment:
        return header
    comment = block.find(_NEWLINE_COMMENT, pos)
    if header < 0:
        return comment
    if comment < 0:
        return header
    return min(header, comment)


def scan_fasta(handle, stats, source):
    """Accumulate one FASTA stream into `stats`. Returns the record count added.

    Reads fixed-size binary blocks and walks each block from one line marker to
    the next, handing whole runs of sequence bytes to the accumulator in one go.
    Memory is bounded by the block size regardless of how long a single record
    is, so a one-contig 3 Gb assembly costs no more than a set of short reads.
    """
    added = 0
    seen_first = False   # a '>' header has been seen, so a record is open
    in_header = False    # mid-way through a header or comment line
    carry = b""          # withheld trailing newline, so a marker split across
                         # two blocks is still recognised

    while True:
        chunk = handle.read(_BLOCK_SIZE)
        if not chunk:
            break
        block = carry + chunk
        # Withhold a trailing newline. It carries no residues, so holding it
        # back cannot change any count, and it lets the next block match a
        # marker that straddles the boundary.
        if block.endswith(b"\n"):
            block, carry = block[:-1], b"\n"
        else:
            carry = b""

        pos = 0
        end = len(block)
        has_comment = _NEWLINE_COMMENT in block
        while pos < end:
            if in_header:
                newline = block.find(b"\n", pos)
                if newline < 0:
                    pos = end          # header runs on into the next block
                    break
                in_header = False
                pos = newline + 1
                continue

            # pos is always at the start of a line here.
            marker = block[pos]
            if marker == _HEADER:
                if seen_first:
                    added += stats.close_record()
                seen_first = True
                in_header = True
                pos += 1
                continue
            if marker == _COMMENT:
                in_header = True       # legacy FASTA comment line, no record
                pos += 1
                continue
            if not seen_first:
                if block[pos : pos + 1].isspace():
                    pos += 1
                    continue
                raise ValueError("%s: sequence data before any '>' header" % source)

            next_marker = _next_line_marker(block, pos, has_comment)
            if next_marker < 0:
                stats.add_residues(block[pos:end])
                pos = end
            else:
                stats.add_residues(block[pos : next_marker + 1])
                pos = next_marker + 1

    if seen_first:
        added += stats.close_record()
    return added


def collect(paths, stats):
    """Scan every input path into `stats`. Returns [(path, n_records)]."""
    per_file = []
    for path in paths:
        handle = open_fasta(path)
        try:
            per_file.append((path, scan_fasta(handle, stats, path)))
        finally:
            if handle is not sys.stdin.buffer:
                handle.close()
    return per_file


# -- reporting -----------------------------------------------------------

_NX_FRACTIONS = (("N25", 0.25), ("N50", 0.50), ("N75", 0.75))


def as_dict(stats, per_file, bin_size, sparse):
    report = {
        "tool": "countfasta.py",
        "version": __version__,
        "bin_size": bin_size,
        "input_files": [{"path": path, "sequences": n} for path, n in per_file],
        "total_sequences": stats.n_records,
        "total_length": stats.total_length,
        "empty_sequences": stats.empty_records,
        "min_length": stats.min_length,
        "max_length": stats.max_length,
        "mean_length": round(stats.mean_length, 2),
        "gc_count": stats.gc_count,
        "gc_percent": round(stats.gc_percent, 2),
        "n_count": stats.n_count,
        "n_percent": round(stats.n_percent, 2),
        "other_count": stats.other_count,
        "histogram": [
            {"start": start, "end": end, "count": count}
            for start, end, count in stats.histogram(bin_size, sparse)
        ],
    }
    for label, fraction in _NX_FRACTIONS:
        nx = stats.nx(fraction)
        report[label.lower()] = (
            None if nx is None else {"length": nx[0], "sequences_at_or_above": nx[1]}
        )
    return report


def write_text(stats, per_file, bin_size, sparse, out):
    def row(label, value):
        out.write("%-30s %s\n" % (label, value))

    out.write("# countfasta.py v%s - VIB Nucleomics Core\n" % __version__)
    out.write("# input files (%d):\n" % len(per_file))
    for path, n in per_file:
        out.write("#   %s (%d sequences)\n" % (path, n))
    out.write("# histogram bin size: %d residues\n" % bin_size)

    out.write("\n--- Length histogram ---\n")
    histogram = stats.histogram(bin_size, sparse)
    if not histogram:
        out.write("(no sequences with length > 0)\n")
    for start, end, count in histogram:
        out.write("%d:%d\t%d\n" % (start, end, count))

    out.write("\n--- Summary ---\n")
    row("Total number of sequences", stats.n_records)
    row("Total length of sequence", "%d bp" % stats.total_length)
    if stats.empty_records:
        row("Zero-length sequences", stats.empty_records)
    row("Shortest sequence", "%d bp" % stats.min_length)
    row("Longest sequence", "%d bp" % stats.max_length)
    row("Mean length", "%.2f bp" % stats.mean_length)
    for label, fraction in _NX_FRACTIONS:
        nx = stats.nx(fraction)
        if nx is None:
            row(label, "n/a")
        else:
            row(label, "%d bp (%d sequences >= %d bp)" % (nx[0], nx[1], nx[0]))
    row("Total GC count", "%d bp" % stats.gc_count)
    row("GC %", "%.2f %%" % stats.gc_percent)
    row("N count", "%d bp (%.2f %%)" % (stats.n_count, stats.n_percent))
    row("Other/ambiguous count", "%d bp" % stats.other_count)


# -- CLI -----------------------------------------------------------------

def parse_bin_size(raw):
    """Coerce -i to a positive int; anything else falls back to the default."""
    if raw is None:
        return DEFAULT_BIN_SIZE
    try:
        value = int(raw)
    except (TypeError, ValueError):
        sys.stderr.write(
            "warning: -i '%s' is not an integer, using default bin size %d\n"
            % (raw, DEFAULT_BIN_SIZE)
        )
        return DEFAULT_BIN_SIZE
    if value <= 0:
        sys.stderr.write(
            "warning: -i %d is not positive, using default bin size %d\n"
            % (value, DEFAULT_BIN_SIZE)
        )
        return DEFAULT_BIN_SIZE
    return value


def build_parser():
    parser = argparse.ArgumentParser(
        prog="countfasta.py",
        description="Report FASTA length distribution and assembly summary statistics.",
        epilog="Created by %s" % __author__,
    )
    parser.add_argument(
        "fasta", nargs="+", metavar="FASTA",
        help="one or more FASTA files (plain or gzipped), or '-' for stdin; "
             "statistics are aggregated over all of them",
    )
    parser.add_argument(
        "-i", dest="bin_size", metavar="BIN",
        help="histogram bin size in residues (default: %d; "
             "a non-integer or non-positive value falls back to the default)"
             % DEFAULT_BIN_SIZE,
    )
    parser.add_argument(
        "--sparse", action="store_true",
        help="omit empty histogram bins (useful for assemblies with few long contigs)",
    )
    parser.add_argument(
        "--json", action="store_true",
        help="emit the report as JSON instead of plain text",
    )
    parser.add_argument(
        "--n50-only", action="store_true",
        help="print only the N50 length in bp, for use in pipelines",
    )
    parser.add_argument("--version", action="version", version="countfasta.py %s" % __version__)
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    if args.json and args.n50_only:
        sys.stderr.write("error: --json and --n50-only are mutually exclusive\n")
        return 2

    bin_size = parse_bin_size(args.bin_size)
    stats = FastaStats()
    try:
        per_file = collect(args.fasta, stats)
    except (OSError, ValueError) as err:
        sys.stderr.write("error: %s\n" % err)
        return 1

    if stats.n_records == 0:
        sys.stderr.write("warning: no FASTA records found in the given input\n")

    if args.n50_only:
        nx = stats.nx(0.50)
        sys.stdout.write("%d\n" % (0 if nx is None else nx[0]))
    elif args.json:
        json.dump(as_dict(stats, per_file, bin_size, args.sparse), sys.stdout, indent=2)
        sys.stdout.write("\n")
    else:
        write_text(stats, per_file, bin_size, args.sparse, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
