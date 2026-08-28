# MEMORY.md — pacbio-tools

## Now / Next

**Goal:** close GitHub issue #2 — ship `qc-tools/countfasta.py`, a clean-room VIB
reimplementation of the removed third-party `countFasta.pl` (UC Davis, no licence grant).

**State: authored, tested, AND verified head-to-head against the original. NOT committed.**

Working tree (on `main`, nothing staged):

```
M NOTICE.md      # "will ship" -> "now ships", + how the clean-room wall was kept
M README.md      # new ## qc-tools section + TOC entry + differences table (2 rows added 2026-08-28)
?? qc-tools/     # countfasta.py (444 l), test_countfasta.py (236 l, 22 tests)
?? MEMORY.md     # this file -- decide whether it is committed or stays local
```

**Verification is COMPLETE (2026-08-28).** `python3 qc-tools/test_countfasta.py` -> 22 tests OK,
and the head-to-head against the removed Perl now ran (the auto-mode block that stopped it in the
previous session no longer applies). Results:

- **491 MB / 2000-sequence assembly: every reported quantity MATCHES** -- total length 505,978,661,
  2000 sequences, GC count 232,819,136, GC 46.01%, N25 433,345 (271 seqs), N50 349,266 (594),
  N75 246,502 (1020), 4984 histogram bins with identical per-bin counts. Only the documented
  bin-label base differs (`1500:1599` vs `1501:1600`). Runtime for both tools together: 7.6 s.
- 9 edge-case fixtures: all differences trace to a documented row in the README table. Two that
  were *not* yet documented were found and have now been added to that table: zero-length records
  (`>a` with no sequence) are counted by us and dropped by the original; residues before the first
  `>` header are an error for us and silently ignored by the original. Both were already
  deliberate and already pinned by tests -- only the docs were behind.
- The one apparent Python traceback was in the *comparison harness*, not in `countfasta.py`:
  the harness tried to parse an empty JSON file after our tool correctly refused the input.
  `countfasta.py` itself prints `error: ...: sequence data before any '>' header` and exits 1.
- Clean-room wall still intact: the Perl was executed but never read; the harness prints numbers only.

**Next action:** on the user's word -- branch off `main`, commit, close issue #2 with a resolution
comment. Nothing technical is outstanding.

The comparison harness (still alive at the previous session's scratchpad, may vanish):
`.../86d473ae-.../scratchpad/compare_to_original.sh <file.fasta>` -- extracts `countFasta.pl` from
`d3a9125^` into a temp dir outside the repo, runs both, prints a numbers-only table, deletes the
Perl on exit.

## Key decisions (this session)

- **Language = Python**, decided on measurements, not taste. On a 491 MB synthetic assembly:
  C++ 0.83 s / Perl 2.13 s / numpy 2.38 s / **shipped Python 4.37 s** / naive Python 10.34 s.
  C++ was rejected: only ~5x, and it needs a build step in a repo that has none. Perl was
  rejected on *licensing*, not speed — same language + same task + same output makes
  accidental convergence on the original's expression likely and hard to defend.
- **Histogram bins stay 1-based** (`1:100`, `101:200`; length 100 -> first bin). The original
  was 0-based (`0:99`, `100:199`). Documented in README, pinned by a test. This is the one
  change an external parser would notice.
- **Clean-room wall kept intact.** The implementing agent never read the Perl. A separate
  walled subagent read it and emitted a behaviour-only manifest (no code, syntax, identifiers
  or algorithm description). The user chose this over a direct read.
- Original's reported quantities are a **strict subset** of the replacement's — the extractor
  looked specifically for extras and found none.
- **No callsites ever existed.** Searched every revision, every path, case-insensitively,
  plus `strings` on the wiki PDFs: only `NOTICE.md` has ever mentioned `countFasta`. The
  "swap" is therefore additive only — nothing to rewire.

## Original's bugs deliberately NOT reproduced

Recorded because they will make our numbers differ from the old output, legitimately:

- byte-identical FASTA headers were **merged** into one sequence of summed length
- CRLF (Windows) FASTA: every sequence line dropped -> reported **all zeros**
- empty input: fatal division-by-zero part-way through the report, no `GC %` line
- N25/50/75 count was the *rank* of the threshold sequence, contradicting its own printed
  sentence ("the N sequences >= L"); ours counts all sequences at or above the threshold
- no gzip, no stdin, no `-h`, no `--version`; invalid `-i` silently defaulted (ours warns)

## Verification method (reproducible)

```bash
python3 qc-tools/test_countfasta.py     # 22 tests, stdlib only -> OK
```

Also done, in the (ephemeral) scratchpad: a naive line-based oracle and a naive whole-file
verifier written from the manifest definitions, both structurally unlike the shipped block
scanner. 10/10 edge-case agreement and full agreement on a 491 MB file across 9 configs.
Worth rebuilding if the implementation changes shape again.

**Perf trap already hit once, do not reintroduce:** searching for the legacy `\n;` comment
marker once per *record* costs a full scan of the remaining block every time (9.25 s -> 4.37 s
when hoisted to once per *block* via `has_comment`). Profile before optimising: the first
"optimisation" attempt (bytes instead of str) changed nothing because the real cost was the
per-line Python loop, not the character counting.

## Blocked / needs the user

- Nothing technical. The only open item is the user's go-ahead to branch, commit and close
  issue #2 (and a decision on whether `MEMORY.md` itself is committed).
- Resolved 2026-08-28: the auto-mode block on `git show d3a9125^:qc-tools/countFasta.pl` and on
  running `perl` no longer applies, so the head-to-head ran inside the session after all.
