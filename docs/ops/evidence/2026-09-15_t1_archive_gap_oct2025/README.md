# T1 tick-archive gap 2025-10-09 .. 2025-11-03 — read-only root-cause

Task: read-only forensic follow-up to `9e0fb916` F5 ("Major finding") in
`docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/README.md`. Parent ticket
spec: `docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/followup_ticket_t1_archive_gap.json`.

**Disposition: DIAGNOSED. The ~25-day gap is a source-import hole baked into the
signed Variant-A archive at build time (2026-08-09), farm-wide across all
terminals AND the DL-085 master tree. It is NOT a DL-085 archive-eater deletion
(no on-disk drift from the signed manifest) and NOT a CopyTicksRange serving
defect. No repair executed — proposal only.**

Nothing was mutated: no terminal64.exe started, no archive/manifest/DB write, no
containment/hold/verdict change. The farm DB was opened `mode=ro`. Containment
flag checked and unchanged: `D:/QM/strategy_farm/state/custom_history_containment_mode.json`
shows `enabled: false` (reason `ceo_release_after_copy_on_claim_trip4_20260902`) —
**no active containment event.**

Manifest under test (the signed Variant-A archive manifest, OWNER `APPROVED`
2026-08-07, `claude_review_verdict=APPROVED`):
`D:/QM/strategy_farm/artifacts/ops/custom_history_custom_history_variant_a_20260809/archive_manifest_owner_approved.json`
- `manifest_sha256` (self-reported): `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- `source_custom`: `D:\QM\mt5\T1\Bases\Custom` — i.e. the manifest hashes were
  built *from T1's own archive*, so a byte-for-byte match on T1 only proves T1
  still equals what was signed; it does **not** prove the signed content was
  itself complete. The size analysis (below) is what shows it was not.
- covers **37** DWX symbols for ticks; each has `202510.tkc` and `202511.tkc`
  entries with expected `size` + `sha256` (`hash_mode: SHA256_FULL`).

Re-runnable scripts in this directory:
- `compare_tkc_vs_manifest.py` — Q1/Q2 (sha256 `10371c441fdd766b249c1b2ace6dd1c3de63db4636631b362a5c0e85f1fe6771`)
- `q3_affected_work_items.py` — Q3 (sha256 `44a7ae3119f73566c173dda7da58f7c730f25c7cb95c8885ec872d152cfa29ae`)

CSV outputs:
- `q1q2_tkc_vs_manifest.csv` (sha256 `2241a13c943c62d63a755c23bb6afd9f65a93f833a0c741bfc829a289fef2778`) — 234 rows (3 terminals × 39 symbol-dirs-considered × 2 months, minus dirs absent on a terminal)
- `q3_affected_work_items.csv` (sha256 `2207958a055f61122d66450efc4fa41761f6af32319e96dd1c3953a2f3877807`) — 5902 rows

---

## Q1 — Is the gap in the on-disk archive, or only in the serving path? (T1)

**Answer: in the archive *content*, present since manifest build. The `.tkc`
files on disk are byte-identical to the signed manifest — but the October files
for the affected symbols are ~75% short, and the manifest itself records those
short sizes. So the hole is not a later deviation from the signed state; it was
signed short.**

### Q1a — on-disk vs signed manifest (T1, all 37 covered symbols + 2 uncovered dirs, 202510 & 202511)

`compare_tkc_vs_manifest.py` computes each file's actual size + full sha256 and
compares to the manifest entry. Result for T1:

| Classification | Count | Meaning |
|---|---|---|
| INTACT | 74 | 37 symbols × 2 months, size **and** sha256 match the signed manifest exactly |
| HOLE | 0 | no on-disk deviation from signed state anywhere |
| UNVERIFIABLE | 4 | `JPN225.DWX` and `XBRUSD.DWX` (× 202510/202511) exist on disk but have **no manifest entry** — the manifest's tick coverage is 37 symbols, these two are not among them, so completeness cannot be judged |

Full per-row detail (including disk size / manifest size / both sha256 values)
is in `q1q2_tkc_vs_manifest.csv`.

**So there is zero manifest-vs-disk drift** — the DL-085 archive-eater signature
(a file deleted or shrunk *after* signing, showing as size/sha mismatch, cf.
`docs/ops/evidence/2026-08-10_ramp10_serialization_gate_statonly_fix.md` where
foreign inodes are STAT_ONLY-verified against manifest size) **is absent.**

### Q1b — the signed content is itself short (the actual hole)

The manifest was signed with anomalously small October files for one cohort.
Monthly `.tkc` sizes read directly from the manifest (bytes):

| Symbol | 202508 | 202509 | **202510** | 202511 | 202512 |
|---|--:|--:|--:|--:|--:|
| AUDCAD.DWX | 6,678,340 | 7,046,552 | **1,750,917** | 7,184,498 | 6,186,325 |
| GBPUSD.DWX | 7,059,962 | 7,640,377 | **2,091,648** | 7,549,326 | 6,762,552 |
| NZDJPY.DWX | 7,679,129 | 7,232,809 | **2,080,300** | 7,854,358 | 6,555,322 |
| EURUSD.DWX | 5,694,375 | 6,026,135 | **1,656,896** | 4,618,485 | 4,098,384 |
| XAUUSD.DWX *(control)* | 15,374,271 | 20,232,577 | **31,927,474** | 24,094,856 | 24,759,495 |
| GDAXI.DWX *(control)* | 1,687,204 | 1,759,379 | **2,326,780** | 2,375,224 | 1,360,152 |

For the FX cohort, 202510 is ~23-27% of its neighbours (only ~Oct 1-8 present
before the hole opens 2025-10-09); 202511 is roughly normal (hole closes
2025-11-03, only the Nov 1-2 weekend missing). Control symbols (index/metal)
show a **normal or larger** October — they are not part of this hole. This
matches the F5 reconciler finding to the minute
(`longest_weekday_gap_start_broker_epoch=1759978740`=2025-10-09T02:59Z,
`..._end=1762128300`=2025-11-03T00:05Z).

### Q1c — archive-content hole vs CopyTicksRange serving defect

Decided **archive-content hole**, on two independent lines of evidence:
1. The file bytes for the cohort's 202510 are physically ~75% smaller than
   sibling months — a serving/`CopyTicksRange` defect would leave the on-disk
   file full-sized and only mis-serve the window; it does not shrink the file.
2. The F5 re-run reached the identical window via MT5 `CopyTicksRange` over these
   very files and found the same gap
   (`docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/README.md`, "Major
   finding"). Short-on-disk **and** empty-when-served = the ticks were never in
   the archive, not withheld by the serving path.

Definitive tick-level confirmation would require an MT5 `CopyTicksRange` dump
(forbidden here — no terminal start); the F5 export already supplied that leg.

---

## Q2 — Do other terminals show the same hole?

**Answer: farm-wide, not T1-specific.** `compare_tkc_vs_manifest.py` ran the same
size+sha256 check for T2 and T5:

| Terminal | INTACT | HOLE | UNVERIFIABLE |
|---|--:|--:|--:|
| T1 | 74 | 0 | 4 |
| T2 | 74 | 0 | 4 |
| T5 | 74 | 0 | 4 |

Every terminal carries byte-identical `.tkc` files — the same signed, short
October. This is expected: Variant-A cutover distributes one signed archive to
all of T1-T10, so a hole in the signed source propagates uniformly. The DL-085
**master tree** (`D:\QM\archive\Custom_master`, bound to the same
`manifest_sha256`) was also spot-checked and carries the identical short files
(AUDCAD/GBPUSD 202510 byte-identical to manifest). **Consequence: any
restore-from-master or re-verify-against-manifest repair reproduces the hole —
it cannot fill it** (see Q4).

---

## Q3 — Which backtest work items are affected?

`q3_affected_work_items.py` (DB opened `file:...farm_state.sqlite?mode=ro`).
`work_items` schema was inspected first (`.schema`): the run terminal lives in
`payload_json.terminal`, and window bounds in `data_window_start` /
`data_window_end` (coalesced with `payload_json.from_date`/`to_date`), stored as
mixed `YYYY.MM.DD` / bare-year / ISO strings — all normalized in the script.

Overlap test: `window_start <= 2025-11-03 AND window_end >= 2025-10-09`. Because
the gap is farm-wide, no terminal filter is applied; each row records the
terminal it ran on. The Oct-hole FX cohort is derived empirically (not
hand-asserted): a symbol is "in cohort" iff its manifest `202510 size / 202509
size < 0.40`. That yields **27 symbols — every FX pair in the archive** (a
superset of the "~21" the F5 prose named, because F5 only listed the ones it
sorted by hand).

**Totals (see `q3_affected_work_items.csv`):**

- **5,902** rows have a window overlapping the gap dates.
- **5,005** are `verdict-relevant` (had a non-empty verdict); **897** are
  `not-verdict-relevant` (window overlaps but no verdict — pending/active/NULL).
- Of the 5,005 verdict-relevant, only **1,657** are for a **data-short cohort
  symbol**. The other **3,348** are index/commodity ("control") symbols whose
  October is normal — their window overlaps the gap *dates* but their data in
  that window is intact, so the gap did not corrupt them.

**The 1,657 cohort-symbol verdict rows split by phase:**

| Bucket | Count | Notes |
|---|--:|---|
| OPT_CENSUS | 1,435 | optimization census, not a pass/fail pipeline gate |
| **Pipeline gates (Q02-Q11)** | **222** | Q02 11, Q03 2, Q04 2, Q05 52, Q06 29, Q07 45, Q08 13, Q09 58, Q11 10 |

The 222 gate verdicts break down: **155 PASS, 38 FAIL, 9 INVALID, 8 INFRA_FAIL,
5 FAIL_HARD, 4 FAIL_DD_PORTFOLIO_REVIEW, 3 PASS_SOFT**. The 155 PASS are the
integrity concern — a passing gate verdict computed over a window that silently
lost ~25 days for that symbol. All cohort rows end 2025-12-31 (1,655) or later
(2 end 2026-12-31).

**Materiality caveat (evidence-bound, not smoothed):** the gap is ~25 calendar
days inside windows that typically span 2018-07-02 .. 2025-12-31 (~2,700 days) —
**under 1% of the data**, in the OOS tail. So while 222 gate verdicts are
formally `verdict-relevant`, the expected distortion per verdict is small; this
is an evidence-hygiene issue (a hole ran without being declared), not
necessarily a verdict-flipping one. Per-row detail — id, ea_id, symbol, phase,
status, verdict, verdict_taxonomy, window, terminal, `symbol_in_oct_cohort`,
`oct_size_ratio_vs_sep`, `evidence_relevance`, evidence_path — is in
`q3_affected_work_items.csv` so each row can be judged individually.

---

## Q4 — Repair proposal (proposal only; nothing executed)

**Why the cheap repair does not work:** the hole is in the signed source, and the
manifest, all T1-T10 archives, and the DL-085 master tree are byte-identical
short copies. `custom_history_master.py` (repair-first restore) and any
re-verify-against-manifest step therefore **cannot** fill the gap — they only
guarantee the terminals equal the (short) signed state. New tick data must be
sourced.

**Scope of missing data:** months **202510** (and the Nov 1-2 sliver in
**202511**) for the **27 FX-pair `.DWX` symbols**, on the archive source
(applies to all terminals once re-cut). Index/metal symbols are not affected.

**Two governed paths already exist (no new tool needed):**

1. **DWX-native re-download + re-sign (authoritative, matches the existing
   archive provenance).** In a controlled terminal, re-pull Darwinex `.DWX`
   broker history for the 27 FX symbols over 2025-10..2025-11, then rebuild and
   OWNER-re-sign the archive:
   - `tools/strategy_farm/custom_history_contract.py` — rebuilds/validates the
     content-addressed manifest from the refreshed Custom tree.
   - `tools/strategy_farm/custom_history_master.py` — rebuilds the master tree
     from the sha-verified sources.
   - `tools/strategy_farm/custom_history_migration.py --execute` — OWNER-gated
     staging/cutover/activation to T1-T10 (requires the new OWNER-approved
     manifest + detached approval receipt; dry-run by default). **ROT** — touches
     the signed archive, so OWNER sign-off is mandatory.

2. **Dukascopy backfill/splice (the pipeline already being built for exactly this
   class).** `tools/dukascopy/download_bi5.py` -> `convert_to_import.py` ->
   `reconcile_overlap.py` produce reconciled M1 for the window; a production
   splice would fill the archive from Dukascopy. **Currently not authorized** —
   `production_splice_authorized=false` everywhere as of the r2 ticket — so this
   path needs the splice-authorization work item to land first.

**Recommended: path 1** (keeps the archive single-sourced from DWX, which is also
the live-book history source), with path 2 usable only as a cross-check until
splice is authorized.

**Cost estimate (factory time):**
- Data re-pull + manifest/master rebuild + cutover: bounded by file copy, not
  backtesting — the affected files are 27 symbols × ~2 months × ~7 MB ≈ 0.4 GB
  per terminal; a 10-terminal cutover is minutes of I/O, plus the terminal
  session needed for the DWX re-download. Order **< 1 terminal-hour** of factory
  time (dominated by the interactive history download, not compute).
- Restoring evidence integrity by **re-running affected verdicts** is the real
  cost: ~1,657 cohort verdict rows (222 pipeline gates + 1,435 OPT_CENSUS). At an
  order-of-magnitude throughput of ~10 cell-runs / terminal-hour across 10
  terminals, that is roughly **15-20 terminal-hours**. *(Throughput is the
  uncertain input — recent census cadence has been ~9 cells/h/slot; scale
  linearly if that figure is refreshed.)* Given the <1% materiality (Q3), a
  cheaper option is to re-run only the **155 PASS** gate verdicts (the ones whose
  integrity actually matters for promotion), ≈ 1-2 terminal-hours.

None of the above is executed here. Recommended sequencing: OWNER decides path 1
vs 2 and re-run scope; the re-download + re-sign is a ROT action requiring OWNER
approval before any cutover.

---

## Exact commands run (all read-only)

```
# Q1/Q2
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/compare_tkc_vs_manifest.py
# -> T1/T2/T5 each {INTACT:74, UNVERIFIABLE:4}; writes q1q2_tkc_vs_manifest.csv

# Q3 (DB read-only)
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/q3_affected_work_items.py
# -> 5902 overlapping; 5005 verdict-relevant; 1657 cohort; 222 pipeline gates
#    (155 PASS/38 FAIL/...); writes q3_affected_work_items.csv

# schema inspection
sqlite3 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro' '.schema work_items'
```

Master-tree confirmation (root `D:\QM\archive\Custom_master`, state file
`D:/QM/strategy_farm/state/custom_history_master_root.json`): AUDCAD/GBPUSD
`202510.tkc` byte-identical to manifest (size + sha256 match).
