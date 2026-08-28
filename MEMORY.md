# MEMORY.md — pacbio-tools

## Now / Next

**Goal:** close GitHub issue #2 — ship `qc-tools/countfasta.py`, a clean-room VIB
reimplementation of the removed third-party `countFasta.pl` (UC Davis, no licence grant).

**State: DONE except the merge. PR #3 is open and awaits the user's merge click.**

- Branch `qc-tools/countfasta-py`, 2 commits, pushed to origin.
  - `a93f311` qc-tools: add countfasta.py (+ NOTICE.md, README.md)
  - `4bfe45b` docs: add MEMORY.md
- **PR https://github.com/Nucleomics-VIB/pacbio-tools/pull/3** — body says `Closes #2`, so
  issue #2 auto-closes on merge.
- Resolution comment posted on issue #2 (`#issuecomment-5456861919`) with the full
  verification table and the clean-room account.

**The ONLY outstanding action: merge PR #3.** The auto-mode classifier blocked
`gh pr merge 3 --rebase --delete-branch`, so the user runs it (rebase keeps this repo's
linear history), or merges from the GitHub UI. Afterwards, locally:
`git checkout main && git pull --ff-only && git branch -d qc-tools/countfasta-py`.

**Verification is COMPLETE (2026-08-28).** `python3 qc-tools/test_countfasta.py` -> 22 tests OK,
and the head-to-head against the removed Perl ran in-session:

- **491 MB / 2000-sequence assembly: every reported quantity MATCHES** -- total length 505,978,661,
  2000 sequences, GC count 232,819,136, GC 46.01%, N25 433,345 (271 seqs), N50 349,266 (594),
  N75 246,502 (1020), 4984 histogram bins with identical per-bin counts. Only the documented
  bin-label base differs (`1500:1599` vs `1501:1600`). Runtime for both tools together: 7.6 s.
- 9 edge-case fixtures: all differences trace to a documented row in the README table. Two that
  were *not* yet documented were found and added to that table: zero-length records (`>a` with no
  sequence) are counted by us and dropped by the original; residues before the first `>` header
  are an error for us and silently ignored by the original. Both were already deliberate and
  already pinned by tests -- only the docs were behind.
- The one apparent Python traceback was in the *comparison harness*, not in `countfasta.py`.
- Clean-room wall intact: the Perl was executed but never read; the harness prints numbers only.

The comparison harness (previous session's scratchpad, may vanish):
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

- **Merge PR #3.** `gh pr merge 3 --rebase --delete-branch` was blocked by the auto-mode
  classifier; it is the last step and has to come from the user. Nothing else is outstanding.
- Resolved 2026-08-28: the earlier block on `git show d3a9125^:qc-tools/countFasta.pl` and on
  running `perl` no longer applies, so the head-to-head ran inside the session after all.
