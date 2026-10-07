# Notice

**This repository is licensed under the [GNU General Public License v3.0](LICENSE)**, except
for the four files listed under *Third-party material* below. Those files keep the licence of
their upstream source.

## Parts authored by VIB Nucleomics Core

Everything not listed below was written at the **VIB Nucleomics Core**, the sequencing
facility of [VIB](https://www.vib.be). Copyright © VIB Nucleomics Core. Licensed under
GPL-3.0. Attribute it to *VIB Nucleomics Core*.

## Third-party material at `HEAD`

These files are adapted from code that VIB Nucleomics Core did not write. VIB claims no
ownership of the adapted code. Each file states its licence in its header, and the full
licence text is in [`LICENSES/`](LICENSES/).

| Path | Adapted from | Licence | Licence text |
|---|---|---|---|
| `plotting-tools/plot_reads.R` | pb-falcon documentation, Pacific Biosciences | BSD-3-Clause | [`LICENSES/BSD-3-Clause_PacBio.txt`](LICENSES/BSD-3-Clause_PacBio.txt) |
| `plotting-tools/plot_ovlp-stats.R` | pb-falcon documentation, Pacific Biosciences | BSD-3-Clause | [`LICENSES/BSD-3-Clause_PacBio.txt`](LICENSES/BSD-3-Clause_PacBio.txt) |
| `plotting-tools/data/plot_reads-demo.R` | pb-falcon documentation, Pacific Biosciences | BSD-3-Clause | [`LICENSES/BSD-3-Clause_PacBio.txt`](LICENSES/BSD-3-Clause_PacBio.txt) |
| `smrtlink-tools/explain-LocalContextFlags.html` | Picard `explain-flags.html`, Broad Institute | MIT | [`LICENSES/MIT_Broad-Institute.txt`](LICENSES/MIT_Broad-Institute.txt) |

Upstream sources: <https://github.com/PacificBiosciences/pb-falcon> and
<https://github.com/broadinstitute/picard>.

## Third-party material removed

- **2026-10-07 — two PacBio brand images.** `pictures/pacbio_icon.png` (the README logo) and
  `smrtlink-tools/Sequel_reports/data/pacbio-sequel-hero.jpg` (not used by any file) came
  from Pacific Biosciences with no licence grant. They were removed, not relicensed.
- **2026-08-28 — `qc-tools/countFasta.pl`.** Author Joseph Fass, modified from a script by
  Brad Sickler; Bioinformatics Core, UC Davis Genome Center, obtained via the PacBio FALCON
  tutorial. Copyright (c) 2009 The Regents of the University of California, Davis Campus,
  with no licence grant. It was removed, not relicensed. A VIB-authored replacement,
  `qc-tools/countfasta.py`, was written from a behaviour-only specification by an author who
  never read the original. It contains none of the original code.

Earlier commits in this repository's history still contain the removed files. That history
is a record of what was distributed, not a claim of ownership.

## Licensing history — read this before assuming terms

- Originally distributed under **CC BY-SA 3.0 Unported**, summarised in a `LICENSE.md`
  that no licence scanner could read.
- **2026-08-27:** an organisation-wide sweep replaced it with **GPL-3.0** and claimed VIB
  ownership of the whole repository. That claim was wrong: it covered third-party files.
- **2026-08-28:** the GPL-3.0 `LICENSE` was withdrawn and the repository was marked "mixed
  content, no licence asserted". That notice wrongly said no third-party material remained.
- **2026-10-07:** GPL-3.0 restored for the VIB-authored parts. The four adapted files above
  are marked with their upstream licences, and the two PacBio images were removed.

**A licence already granted cannot be retracted.** Copies obtained while this repository
carried CC BY-SA 3.0 or GPL-3.0 remain available to their holders under those terms **for
the parts VIB Nucleomics Core authored**. Those licences never applied to third-party files,
which were never VIB's to license.
