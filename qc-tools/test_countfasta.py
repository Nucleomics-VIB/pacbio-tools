#!/usr/bin/env python3
"""Regression tests for countfasta.py, with hand-checked expected values.

Run with:  python3 qc-tools/test_countfasta.py
Requires only the python3 standard library.

Created by Stephane Plaisance - VIB Nucleomics Core
script version 1.0.0, 2026_08_28
"""

import gzip
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, "countfasta.py")


def run(args, expect_ok=True):
    proc = subprocess.run([sys.executable, SCRIPT] + args,
                          capture_output=True, text=True)
    if expect_ok and proc.returncode != 0:
        raise AssertionError("countfasta.py failed: %s" % proc.stderr)
    return proc


def report(args):
    return json.loads(run(args + ["--json"]).stdout)


class TempFasta:
    """Write FASTA text to a temporary file, optionally gzipped."""

    def __init__(self, text, gz=False):
        self.text, self.gz = text, gz

    def __enter__(self):
        suffix = ".fasta.gz" if self.gz else ".fasta"
        fd, self.path = tempfile.mkstemp(suffix=suffix)
        os.close(fd)
        opener = gzip.open if self.gz else open
        with opener(self.path, "wt") as fh:
            fh.write(self.text)
        return self.path

    def __exit__(self, *exc):
        os.unlink(self.path)


# Hand-checked reference case.
#   seq1 ACGT          len  4   GC 2 (C,G)   N 0   other 0
#   seq2 GGCC + AA     len  6   GC 4         N 0   other 0
#   seq3 NNNNACGTRY    len 10   GC 2 (C,G)   N 4   other 2 (R,Y)
# totals: 3 records, 20 bp, GC 8 -> 40.00 %, N 4 -> 20.00 %, other 2
# longest-first 10, 6, 4;  N25 target 5 -> 10;  N50 target 10 -> 10;  N75 target 15 -> 6
TINY = ">seq1 first\nACGT\n>seq2\nGGCC\nAA\n>seq3\nNNNNACGTRY\n"


class TestHandChecked(unittest.TestCase):

    def test_reference_case(self):
        with TempFasta(TINY) as path:
            r = report([path])
        self.assertEqual(r["total_sequences"], 3)
        self.assertEqual(r["total_length"], 20)
        self.assertEqual(r["gc_count"], 8)
        self.assertEqual(r["gc_percent"], 40.00)
        self.assertEqual(r["n_count"], 4)
        self.assertEqual(r["n_percent"], 20.00)
        self.assertEqual(r["other_count"], 2)
        self.assertEqual(r["min_length"], 4)
        self.assertEqual(r["max_length"], 10)
        self.assertEqual(r["n25"], {"length": 10, "sequences_at_or_above": 1})
        self.assertEqual(r["n50"], {"length": 10, "sequences_at_or_above": 1})
        self.assertEqual(r["n75"], {"length": 6, "sequences_at_or_above": 2})

    def test_bin_labels_are_one_based(self):
        # Deliberate, documented difference from the removed UC Davis script,
        # which labelled bins 0-based (0:99, 100:199).
        with TempFasta(">a\n%s\n>b\n%s\n" % ("A" * 100, "A" * 101)) as path:
            bins = report([path, "-i", "100"])["histogram"]
        self.assertEqual(bins[0]["start"], 1)
        self.assertEqual(bins[0]["end"], 100)
        # a length of exactly 100 belongs to the FIRST bin
        self.assertEqual(bins[0]["count"], 1)
        self.assertEqual((bins[1]["start"], bins[1]["count"]), (101, 1))

    def test_empty_bins_kept_unless_sparse(self):
        with TempFasta(">a\nA\n>b\n%s\n" % ("A" * 250)) as path:
            full = report([path, "-i", "100"])["histogram"]
            sparse = report([path, "-i", "100", "--sparse"])["histogram"]
        self.assertEqual([b["count"] for b in full], [1, 0, 1])
        self.assertEqual([(b["start"], b["count"]) for b in sparse],
                         [(1, 1), (201, 1)])


class TestNStats(unittest.TestCase):

    def test_tied_lengths_count_all_at_or_above(self):
        # Four 100 bp sequences, total 400. N50 target 200 is reached inside the
        # tie group, and every sequence at or above 100 bp is reported -- this is
        # the correct reading, and differs from the removed script, which
        # reported the rank of the threshold sequence instead.
        with TempFasta("".join(">s%d\n%s\n" % (i, "A" * 100) for i in range(4))) as path:
            r = report([path])
        self.assertEqual(r["n50"], {"length": 100, "sequences_at_or_above": 4})

    def test_n_thresholds_are_non_increasing(self):
        text = "".join(">s%d\n%s\n" % (i, "ACGT" * i) for i in range(1, 40))
        with TempFasta(text) as path:
            r = report([path])
        self.assertGreaterEqual(r["n25"]["length"], r["n50"]["length"])
        self.assertGreaterEqual(r["n50"]["length"], r["n75"]["length"])


class TestInputHandling(unittest.TestCase):

    def test_gzip_matches_plain(self):
        with TempFasta(TINY) as plain, TempFasta(TINY, gz=True) as gz:
            self.assertEqual(report([plain])["total_length"],
                             report([gz])["total_length"])

    def test_multiple_files_are_aggregated(self):
        with TempFasta(TINY) as a, TempFasta(TINY, gz=True) as b:
            r = report([a, b])
        self.assertEqual(r["total_sequences"], 6)
        self.assertEqual(r["total_length"], 40)
        self.assertEqual(r["gc_percent"], 40.00)

    def test_stdin(self):
        proc = subprocess.run([sys.executable, SCRIPT, "-", "--n50-only"],
                              input=TINY, capture_output=True, text=True)
        self.assertEqual(proc.stdout.strip(), "10")

    def test_crlf_is_read_correctly(self):
        # The removed script dropped every CRLF sequence line and reported zeros.
        with TempFasta(">a\r\nACGT\r\n>b\r\nGGCC\r\n") as path:
            r = report([path])
        self.assertEqual((r["total_sequences"], r["total_length"]), (2, 8))

    def test_records_split_across_read_blocks(self):
        # Exercises the block scanner's carry logic: a record far larger than one
        # 4 MiB read block, and many records straddling block boundaries.
        big = ">big\n%s\n" % "\n".join(["ACGT" * 15] * 200000)   # 12 Mb of residues
        many = "".join(">s%d\n%s\n" % (i, "GC" * 31) for i in range(20000))
        with TempFasta(big + many) as path:
            r = report([path])
        self.assertEqual(r["total_sequences"], 20001)
        self.assertEqual(r["max_length"], 12000000)
        self.assertEqual(r["total_length"], 12000000 + 20000 * 62)
        # 'big' is ACGT repeated -> exactly half GC; 'many' is all GC
        self.assertEqual(r["gc_count"], 6000000 + 20000 * 62)

    def test_lowercase_counts_as_residues(self):
        with TempFasta(">a\nacgtACGT\n") as path:
            r = report([path])
        self.assertEqual((r["total_length"], r["gc_count"]), (8, 4))

    def test_whitespace_inside_records_ignored(self):
        with TempFasta(">a\nAC GT\n\n\nAC\tGT\n") as path:
            r = report([path])
        self.assertEqual(r["total_length"], 8)

    def test_legacy_comment_lines_skipped(self):
        with TempFasta(">a\n;a comment\nACGT\n") as path:
            r = report([path])
        self.assertEqual(r["total_length"], 4)


class TestEdgeCases(unittest.TestCase):

    def test_empty_file_reports_zeros(self):
        # The removed script died on a division by zero part-way through.
        with TempFasta("") as path:
            r = report([path])
        self.assertEqual(r["total_sequences"], 0)
        self.assertEqual(r["total_length"], 0)
        self.assertEqual(r["gc_percent"], 0.0)
        self.assertIsNone(r["n50"])
        self.assertEqual(r["histogram"], [])

    def test_header_without_sequence_is_a_zero_length_record(self):
        with TempFasta(">lonely\n") as path:
            r = report([path])
        self.assertEqual(r["total_sequences"], 1)
        self.assertEqual(r["empty_sequences"], 1)
        self.assertEqual(r["histogram"], [])

    def test_duplicate_headers_counted_separately(self):
        # The removed script merged byte-identical headers into one sequence of
        # summed length; each record is its own sequence here.
        with TempFasta(">same\nACGT\n>same\nACGTACGT\n") as path:
            r = report([path])
        self.assertEqual(r["total_sequences"], 2)
        self.assertEqual(r["max_length"], 8)

    def test_data_before_first_header_is_an_error(self):
        with TempFasta("ACGT\n>a\nACGT\n") as path:
            proc = run([path], expect_ok=False)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("before any", proc.stderr)

    def test_missing_file_exits_nonzero(self):
        proc = run(["/nonexistent/nope.fasta"], expect_ok=False)
        self.assertEqual(proc.returncode, 1)


class TestCli(unittest.TestCase):

    def test_invalid_bin_size_falls_back_with_a_warning(self):
        with TempFasta(TINY) as path:
            for bad in ("abc", "0", "-5", "1.5"):
                proc = run([path, "-i", bad, "--json"])
                self.assertIn("default bin size 100", proc.stderr)
                bins = json.loads(proc.stdout)["histogram"]
                self.assertEqual((bins[0]["start"], bins[0]["end"]), (1, 100))

    def test_n50_only_prints_a_bare_integer(self):
        with TempFasta(TINY) as path:
            self.assertEqual(run([path, "--n50-only"]).stdout.strip(), "10")

    def test_json_and_n50_only_are_mutually_exclusive(self):
        with TempFasta(TINY) as path:
            self.assertEqual(run([path, "--json", "--n50-only"],
                                 expect_ok=False).returncode, 2)

    def test_no_arguments_exits_nonzero(self):
        self.assertNotEqual(run([], expect_ok=False).returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
