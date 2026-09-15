# T1 tick-archive gap 2025-10-09 .. 2025-11-03 — read-only forensics (rev 2)

Read-only forensic follow-up to `9e0fb916` F5 ("Major finding") in
`docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/README.md`. Parent ticket
spec: `docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/followup_ticket_t1_archive_gap.json`.

**This is rev 2.** Rev 1 was rejected by a cross-model critic (verdict `GAPS`).
Seven findings were accepted and are reworked here; each is marked **[Fn]** at
the point where it changed the answer. Where rev 1 asserted more than the
evidence carried, the claim is now downgraded in place rather than restated.

## Disposition

**CONFIRMED and LOCALISED, mechanism UNDETERMINED.** T1's signed Variant-A tick
archive is short by ~26 calendar days / 18 weekdays (2025-10-09 .. 2025-11-03)
for **all 28 FX pairs** the manifest covers. The shortfall is confirmed at
**tick/bar-count level**, not only by file size. It is byte-identical across
T1/T2/T5, the DL-085 master tree **and T1's pre-cutover rollback tree**, whose
`.tkc` files were written **2026-05-07** — i.e. the hole predates the 2026-08-09
signing by three months and did **not** originate at signing time as rev 1
claimed. Whether the upstream cause is the import tool or a broker-side data
hole is **UNDETERMINED** — no import log or provenance receipt for the
2026-04/05 bulk write was found read-only. Index/metal symbols are unaffected.
No repair executed — proposal only.

## Scope discipline

Nothing was mutated: no `terminal64.exe` started, no archive/manifest/DB write,
no containment/hold/verdict change. `farm_state.sqlite` was opened
`file:...?mode=ro`. All writes are confined to this directory. Containment flag
checked and unchanged: `D:/QM/strategy_farm/state/custom_history_containment_mode.json`
shows `enabled: false` (reason `ceo_release_after_copy_on_claim_trip4_20260902`)
— **no active containment event.**

Manifest under test (OWNER-signed 2026-08-09T05:47:25Z,
`claude_review_verdict=APPROVED`):
`D:/QM/strategy_farm/artifacts/ops/custom_history_custom_history_variant_a_20260809/archive_manifest_owner_approved.json`
- `manifest_sha256` (self-reported) `fe0dd0fdd90dc26b806044c82fd0d7c35af889a96cbd4d79dece9cfdac3aab06`
- `created_at_utc` `2026-08-09T04:45:04Z`, `source_custom` `D:\QM\mt5\T1\Bases\Custom`
- covers **37** DWX symbols for ticks (28 FX pairs + 9 index/metal/energy)

**DB snapshot note.** `farm_state.sqlite` is live and the factory kept running
during this work. All `work_items` counts below are as of
`2026-09-15T10:00Z` (DB mtime at query time). Re-running the scripts later will
return slightly larger totals; a re-run during this session produced 9 extra
rows, all on control symbols, and 0 dropped rows.

## Artefacts in this directory

| File | sha256 | What |
|---|---|---|
| `compare_tkc_vs_manifest.py` | `10371c441fdd766b249c1b2ace6dd1c3de63db4636631b362a5c0e85f1fe6771` | Q1/Q2 on-disk vs signed manifest (T1/T2/T5) |
| `q1q2_tkc_vs_manifest.csv` | `2241a13c943c62d63a755c23bb6afd9f65a93f833a0c741bfc829a289fef2778` | 234 rows |
| `f4_cohort_threshold_matrix.py` | `5aaafcc18efe7a26de3bf36a7693854b816c76e4d99084e714782beb109a4ac7` | **[F4]** cohort membership at 0.35 / 0.40 / 0.50 for all 37 symbols |
| `f4_cohort_threshold_matrix.csv` | `3523b23bce62ed080f64dcbe8b18e2245c60496235df92e1ee055802e4068f44` | 37 rows |
| `f7_gap_window_tick_counts.py` | `0a6e06c815c107d5211cfc987634bf3ed2e9e1f0c7845d4b603b0097c2b87f5d` | **[F7]** chunk tick counts + per-day M1 bar counts |
| `f7_chunk_tick_counts.csv` | `dec2d0fb0a5d4948f539fbeb4994baaa7c735cdd5f67fab0800e2cf2658237b2` | 222 settled chunks |
| `f7_daily_bar_counts.csv` | `af3cdcd03cea5fbaf16e76316b3ec3c5e98a70656f017f4271ab7e24f84cb66e` | 37 symbols x 41 days |
| `f7_symbol_gap_summary.csv` | `194ad03f68860f67f65df801a9415fa29ab2dcca2659e22b0c28d364e095cfe9` | 37 rows |
| `q3_affected_work_items.py` | `964f28ebf3efe2a691520231cda4c276485af42a8a793934bbafa37a478c25b8` | **[F1][F3][F5]** exposure + per-row materiality |
| `q3_affected_work_items.csv` | `a0f62890a3bc65b3d0ae1f131361ed691f4582db4e90a5b19b427ad02a5cb84e` | 5,911 rows |
| `f2_rerun_cost_model.py` | `f5d3d4a8e5b3b4850ed3c6168f2f35b263c636235f722d4fb3f19223d9e6566a` | **[F2]** measured runtimes + priced re-run |
| `f2_phase_runtime_medians.csv` | `b2dc6d26f6d44fd86aedef36ba6d6eb283e8d9cb1d0710e2375df0183daa1b13` | 20 phases |
| `f2_rerun_cost_estimate.csv` | `be1b1726560677d51f0b1231fc4eba47690144bf24c0ece81a4a0d315274a407` | 3 scopes |

---

## Q1 — Is the gap in the archive content, or only in the serving path?

**Answer: in the archive content, and it predates the signed manifest.**

### Q1a — on-disk vs signed manifest (T1, 202510 + 202511)

`compare_tkc_vs_manifest.py` computes each file's actual size + full sha256 and
compares to the manifest entry.

| Classification | T1 | T2 | T5 | Meaning |
|---|--:|--:|--:|---|
| INTACT | 74 | 74 | 74 | 37 symbols x 2 months, size **and** sha256 match the signed manifest exactly |
| HOLE | 0 | 0 | 0 | no on-disk deviation from signed state anywhere |
| UNVERIFIABLE | 4 | 4 | 4 | `JPN225.DWX` / `XBRUSD.DWX` (x2 months) exist on disk with **no manifest entry** |

**Zero manifest-vs-disk drift** — the DL-085 archive-eater signature (a file
deleted or shrunk *after* signing, showing as size/sha mismatch) is **absent.**
The manifest's own recorded sizes are the short ones.

### Q1b — the signed content is itself short (file-size evidence)

Full table: `f4_cohort_threshold_matrix.csv`. Ratio = `202510 size / 202509 size`:

| Population | n | ratio range |
|---|--:|---|
| FX pairs | 28 | **0.2157 .. 0.4087** |
| index / metal / energy | 9 | **1.1725 .. 2.0808** |

The two populations do not overlap, and the nearest gap between them is wide
(0.4087 vs 1.1725). October 2025 is 22-41% of September for every FX pair and
*larger* than September for every non-FX symbol.

### Q1c — **[F7]** tick/bar-count confirmation (not size inference)

Rev 1 localised the gap from file sizes plus prose-cited epochs. Two count-level
sources now bind it, both from the 2026-09-15T06:35Z DWX M1 overlap export that
ran `CopyTicksRange` against T1's Custom archive
(`D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260915_063500/`,
`export_receipt.json` binds `manifest_sha256 = fe0dd0fd…3aab06`, audit status
`PASS_ISOLATED`):

**(a) Per-chunk tick journal** (`raw/<SYMBOL>_M1_chunks.csv`, `phase=final` row,
`copied` = ticks returned for that 7-day chunk). Example, AUDCAD.DWX:

| chunk (UTC) | ticks copied | status |
|---|--:|---|
| 2025-10-01T03:00 .. 2025-10-08T03:00 | 555,164 | OK |
| 2025-10-08T03:00 .. 2025-10-15T03:00 | 109,366 | OK |
| **2025-10-15T03:00 .. 2025-10-22T03:00** | **0** | **ZERO_TICK_CHUNK** (0 after 3 retries) |
| **2025-10-22T03:00 .. 2025-10-29T03:00** | **0** | **ZERO_TICK_CHUNK** |
| 2025-10-29T03:00 .. 2025-11-05T03:00 | 236,991 | OK |
| 2025-11-05T03:00 .. 2025-11-12T03:00 | 667,355 | OK |

Across the 27 symbols whose export was `COMPLETE`, **21 symbols return
ZERO_TICK_CHUNK for both the 10-15..10-22 and the 10-22..10-29 chunk**, and
2 also for 10-08..10-15. The 6 export-COMPLETE index/commodity symbols have
**zero** zero-chunks in the window.

**(b) Per-day M1 bar counts** (`dwx_m1/<SYMBOL>_M1.csv`, rows per calendar day).
Comparing gap-window weekdays against the same symbol's control weekdays in
2025-10-01..2025-11-10 (`f7_symbol_gap_summary.csv`):

| Population (export-COMPLETE only) | n | gap-weekday M1-bar shortfall |
|---|--:|---|
| FX pairs | 21 | **83.99% .. 94.45%** (15-18 of 18 weekdays have **0** bars) |
| index / metal / energy | 6 | 0.11% .. 2.94% (0 of 18 weekdays empty) |

That is a clean bimodal split at count level, independent of the size evidence.

**Honest limit on (a)+(b):** the same export has a *separate*, already-documented
defect — 10 of 37 symbols came back `SHORT_READ` (a handful of bars for the whole
6-month window), measured in
`docs/ops/evidence/2026-09-15_dukascopy_export_fix_r2/f2_completeness_floor_measurement.csv`.
Those 10 are `EURAUD, EURCHF, EURJPY, EURUSD, GBPAUD, GBPJPY, USDJPY` (FX) and
`NDX, XAUUSD, XNGUSD` (non-FX). For them a zero chunk or zero day proves nothing
about the archive, only that the export failed. They are marked
`count_evidence=UNJUDGEABLE` in the CSVs and are **excluded from the count-level
claim**. Their cohort membership rests on file size alone. So: 21 of 28 FX pairs
are confirmed at count level; 7 rest on size evidence only.

### Q1d — archive-content hole vs `CopyTicksRange` serving defect

Decided **archive-content hole**:
1. The `.tkc` bytes for the cohort's 202510 are physically 75-78% smaller than
   sibling months — a serving defect leaves the file full-size.
2. `CopyTicksRange` over those very files returns **0 ticks** for the two middle
   chunks after 3 retries each (Q1c(a)) while returning millions of ticks for
   adjacent chunks of the same file set. Short-on-disk **and** empty-when-served
   = the ticks were never in the archive.

---

## Q2 — Do other terminals show the same hole?

**Yes, farm-wide, and it predates the cutover.** T1/T2/T5 all report
`{INTACT: 74, UNVERIFIABLE: 4}` — byte-identical `.tkc` files. The DL-085 master
tree (`D:\QM\archive\Custom_master`, state file
`D:/QM/strategy_farm/state/custom_history_master_root.json`, bound to the same
`manifest_sha256`, built 2026-08-14) carries the identical short files.

**New in rev 2:** T1's **pre-cutover rollback tree** still exists at
`D:\QM\mt5\T1\Bases\Custom.__variant_a_rollback__.custom_history_variant_a_20260809`
and was checked read-only. See Q5 — it is the decisive evidence on timing.

**Consequence: any restore-from-master or re-verify-against-manifest repair
reproduces the hole — it cannot fill it.**

---

## Q3 — Which work items are exposed?

`q3_affected_work_items.py` (DB `mode=ro`). Overlap test:
`window_start <= 2025-11-03 AND window_end >= 2025-10-09`, windows read from
`data_window_start`/`data_window_end` coalesced with
`payload_json.from_date`/`to_date` and normalised across the mixed
`YYYY.MM.DD` / ISO / bare-year forms. **5,911** rows overlap.

### Q3a — **[F4]** cohort definition, threshold-explicit

Rev 1 used an unstated `< 0.40` size-ratio rule and reported "27 symbols — every
FX pair". That was wrong on its own terms: the manifest has **28** FX pairs, and
0.40 cuts *inside* the FX population.

| threshold | cohort size | FX pairs in cohort |
|---|--:|--:|
| 0.35 | 19 | 19 |
| **0.40** (rev 1) | **27** | **27** |
| 0.50 | **28** | **28** |

Nine symbols are threshold-sensitive between 0.35 and 0.50: `GBPCAD` 0.3664,
`GBPCHF` 0.3684, `GBPNZD` 0.3689, `EURCHF` 0.3738, `GBPAUD` 0.3794, `AUDCHF`
0.3765, `EURAUD` 0.3848, `EURNZD` 0.3875, **`GBPJPY` 0.4087**. `GBPJPY` is the
one rev 1 silently exonerated as "control" — it was never a control symbol; it
is a cohort member with 6 gate verdicts (Q05 PASS, Q05 FAIL, Q06 PASS, Q07 PASS,
Q08 FAIL_HARD, Q09 PASS). **No non-FX symbol enters the cohort at any threshold
up to 0.50**, and no FX pair escapes it. Any threshold in (0.4087, 1.1725) gives
the same answer, so the cohort is stated as **all 28 FX pairs** and 0.50 is used
as the default. Both 0.40 and 0.50 memberships are emitted per row so the
sensitivity stays auditable.

### Q3b — **[F5]** basket / multi-symbol rows

Rev 1 matched the row's `symbol` literally against the manifest, so a logical
basket name (`FX8_BASKET_D1`, `QM5_*_COINTEGRATION_D1`, …) never matched and
was counted **intact**. Legs are now resolved from `payload_json.basket_symbols`
(present on **31 of 31** multi-symbol rows in the overlap set — no row needed the
`UNJUDGEABLE` fallback, and `UNJUDGEABLE` count is **0**). A row is cohort-exposed
if **any** leg is a cohort symbol.

- 31 multi-symbol rows overlap the gap; **17 are cohort-EXPOSED via their legs**
  (rev 1 called all of them intact).
- **12 of those 17 land in the impact set** — phases/verdicts:
  Q02 PASS 1, Q02 INFRA_FAIL 1, Q02 INVALID 1, Q05 PASS 2, Q06 PASS 2,
  Q07 PASS 1, Q07 FAIL 1, Q07 INFRA_FAIL 2, Q09 PASS 1.
- `FX8_BASKET_D1` (EA `QM5_10717`) declares **28 legs — the entire FX cohort**,
  i.e. every leg is short. It appears 3x in the overlap set.
- 14 multi-symbol rows resolve to purely non-cohort legs (XAU/XAG, XTI/XNG) and
  stay CONTROL.

### Q3c — **[F3]** rows that never read data are a separate class

Rev 1's relevance rule was "verdict string non-empty", which counted census
*pruning decisions* as verdict-relevant. The class is now derived from the data,
not from verdict names: a row is `no-data-read` iff its `payload_json` carries
**no** `claimed_at_iso`, **no** `terminal` and **no** `report_root`.

Measured over the whole `work_items` table, that predicate separates cleanly:

| verdict | rows | with terminal | with report_root | with claimed_at |
|---|--:|--:|--:|--:|
| `SKIPPED_EXCLUDED` | 6,219 | **0** | **0** | **0** |
| `SKIPPED_PRESCREEN` | 5,240 | **0** | **0** | **0** |
| `PASS` | 27,470 | 27,445 | 27,447 | 27,445 |
| `FAIL` | 23,332 | 23,328 | 23,328 | 23,328 |
| `MEASURED` | 19,967 | 19,967 | 19,967 | 19,967 |
| `INFRA_FAIL` | 55,882 | 54,482 | 54,786 | 54,482 |

No worker ever claimed a `SKIPPED_*` row, no terminal ran it, no report root
exists — no tick was read, so the gap cannot have distorted it. Their
`evidence_path` points at census `prescreen`/`pruning` decision JSON, not an MT5
report.

**Effect:** of the 2,199 cohort-exposed overlapping rows, **626 carry a verdict
but never executed** (`SKIPPED_EXCLUDED` 318, `SKIPPED_PRESCREEN` 308) and are
excluded from impact and from re-run cost. A further 524 cohort-exposed rows
never executed and carry no verdict.

### Q3d — the impact set

**Impact set = cohort-EXPOSED AND executed AND has a verdict = 1,047 rows.**
(At rev 1's 0.40 threshold it would be 1,041; the 6-row delta is GBPJPY.)

| Bucket | rows |
|---|--:|
| OPT_CENSUS | 809 |
| **Pipeline gates (Q02-Q11)** | **238** |

Gate phases: Q09 60, Q05 56, Q07 50, Q06 32, Q08 14, Q02 12, Q11 10, Q03 2, Q04 2.
Gate verdicts: **PASS 165**, FAIL 40, INFRA_FAIL 11, INVALID 9, FAIL_HARD 6,
FAIL_DD_PORTFOLIO_REVIEW 4, PASS_SOFT 3.

The **165 PASS + 3 PASS_SOFT** are the integrity concern: a passing gate verdict
computed over a window that silently lost 18 weekdays for that symbol.

### Q3e — **[F1]** materiality, per row, as a distribution

Rev 1 divided the gap by a blanket ~2,700-day window and reported "<1%". That
number does not describe most of the affected rows. Materiality is now computed
per row from the row's **own** window and reported split by window class
(`gap_calendar_days / window_span_days`, and a weekday variant as a trading-day
proxy; the gap is 26 calendar days / 18 weekdays when fully contained):

| Class | rows | materiality (calendar) | materiality (weekday) |
|---|--:|---|---|
| `2025_only_census` (window 2025-01-01..2025-12-31) | 807 | **7.123 %** (uniform: min = median = max) | **6.897 %** |
| `multi_year` | 240 | 0.791 % .. 0.949 % | 0.767 % .. 0.919 % |

Multi-year windows present: `2017-01-01..2025-12-31` (215 rows, 0.791 %),
`2018-07-02..2025-12-31` (23 rows, 0.791 %), `2019-01-01..2026-12-31` (2 rows,
0.949 %).

**The split is almost exactly along the census/gate line, and that matters for
the reading:**

- **All 238 pipeline-gate rows** have multi-year windows -> materiality
  **0.791-0.949 % calendar / 0.767-0.919 % weekday**. For the gate verdicts,
  rev 1's "<1%" happens to be correct — but it was correct by luck, not by
  measurement, since it was derived from an assumed window.
- **807 of the 809 OPT_CENSUS rows** carry the pure-2025 census window ->
  materiality **7.123 % calendar / 6.897 % weekday**, roughly **9x** what rev 1
  reported. Those are the rows where rev 1's blanket number was materially wrong.

So the corrected statement is: materiality is **not** a single number. It is
~0.8 % for the gate verdicts and ~7 % for the 2025-only census cells, and the
7 % population is the larger one (807 vs 238 rows).

**What materiality does *not* settle.** These are calendar-share figures. They
bound how much *data* is missing, not how much a given verdict *moved*. A
regime-concentrated strategy can have a large fraction of its trades inside a
small window. Per-row detail — including `gap_calendar_days`, `gap_weekdays`,
`window_span_days`, `materiality_calendar_pct`, `materiality_weekday_pct`,
`legs`, `exposed_legs`, `cohort_exposure_at_0_50`, `cohort_exposure_at_0_40`,
`executed_backtest`, `evidence_relevance` — is in `q3_affected_work_items.csv`
so any row can be judged individually.

---

## Q4 — **[F2]** Re-run cost, from measured runtimes

Rev 1's "155 PASS gates ~ 1-2 terminal-hours" and "15-20 terminal-hours at ~10
cells/h/slot" were guesses. Both are replaced.

### What `work_items` actually offers

`.schema work_items` confirms there is **no duration column** (columns: `id`,
`kind`, `phase`, `ea_id`, `symbol`, `setfile_path`, `status`, `verdict`,
`attempt_count`, `parent_task_id`, `evidence_path`, `claimed_by`,
`payload_json`, `created_at`, `updated_at`, plus sha/window/contract fields).
Measured wall-clock per executed cell is therefore
`updated_at - payload_json.claimed_at_iso`. `created_at` is enqueue time and
includes arbitrary queue wait, so it is not used. 84,037 of 96,037 `done` rows
carry `claimed_at_iso`; excluded from the sample: 12,000 without it (the
`SKIPPED_*` non-executing rows are the bulk), 478 non-positive, 417 over 3 days
(worker-crash/reclaim artefacts).

Measured medians (`f2_phase_runtime_medians.csv`), seconds:

| phase | n | p25 | **median** | p75 | p95 |
|---|--:|--:|--:|--:|--:|
| Q02 | 27,115 | 133 | **305** | 542 | 1,272 |
| Q03 | 12,590 | 84 | **220** | 297 | 600 |
| Q04 | 18,145 | 210 | **393** | 757 | 1,362 |
| Q05 | 1,199 | 381 | **583** | 925 | 2,396 |
| Q06 | 646 | 407 | **602** | 947 | 2,478 |
| Q07 | 573 | 2,159 | **2,940** | 4,560 | 7,395 |
| Q08 | 786 | 503 | **1,136** | 3,098 | 8,257 |
| Q09 | 308 | 623 | **853** | 1,112 | 1,607 |
| Q11 | 33 | 460 | **660** | 1,036 | 1,389 |
| OPT_CENSUS | 20,323 | 140 | **177** | 237 | 458 |

**On `framework/registry/tester_defaults.json`.** The critique cited
`p2_real_tick_policy.full_run.timeout_seconds_min/max = 7200/14400` as a 2-4 h
per-run *budget*. Reading the file, that field is a **timeout ceiling**, not an
expected runtime — its own `timeout_basis` says "sized from the six-month
pre-screen runtime with headroom multipliers". The measured Q02 median (305 s)
being ~24-47x under the ceiling is what a headroom-sized timeout is supposed to
look like. So neither rev 1's throughput guess nor the 2-4 h reading of the
registry is used; the medians above are.

### Measured parallelism (not assumed)

An interval-overlap sweep over the last 7 days of completed cells
(2026-09-08 .. 2026-09-15T09:53Z, 10,193 intervals) gives:

- **peak = 10** concurrent cells
- **time-weighted mean = 4.92** concurrent cells
- terminals observed: **T1-T10** (10 factory terminals; `farmctl mt5-slots`
  reports terminal-worker processes under T1-T10 only; `disabled_terminals.txt` lists
  only T11/T12, which do not exist as slots)

The mean is well below the peak because the factory is not saturated
continuously. Both figures are reported; the mean is the realistic planning
number and the peak is the floor.

### Priced re-run (`f2_rerun_cost_estimate.csv`)

Each impact-set row is charged its own phase's measured median (and p75 as an
upper bound):

| Scope | rows | terminal-h @ median | terminal-h @ p75 | wall-clock h @ mean 4.92 | wall-clock h @ peak 10 |
|---|--:|--:|--:|--:|--:|
| A — all cohort-exposed executed rows | 1,047 | **116.9** | 175.3 | **23.7** | 11.7 |
| B — pipeline gates only | 238 | **77.1** | 122.0 | **15.7** | 7.7 |
| C — PASS-like gates only | 168 | **54.6** | 82.4 | **11.1** | 5.5 |

Scope C (`PASS` / `PASS_SOFT` / `PASS_LOWFREQ` gate rows) is the minimum
defensible re-run if OWNER wants only promotion-relevant integrity restored:
Q09 48, Q07 37, Q05 31, Q06 31, Q02 10, Q11 10, Q04 1.

**vs rev 1:** rev 1 said the 155 PASS gates were "1-2 terminal-hours". Measured,
the comparable scope C is **54.6 terminal-hours** — rev 1 was low by ~30-50x, and
the full scope A is **116.9 terminal-hours**, not 15-20. The direction of rev 1's
error was optimism, not the ~100x pessimism the critique assumed from the
timeout ceiling.

**Caveats, stated rather than smoothed:** (i) medians are drawn from all
historical runs of each phase, not only cohort-symbol runs — FX single-symbol
cells are typically cheaper than index cells, so scope A/B may be slightly
over-priced; (ii) these are wall-clock claim-to-verdict times and include worker
overhead (copy-on-claim, archive audit), which is the honest cost of scheduling a
re-run; (iii) the estimate assumes re-running at current concurrency with no
other work in the queue, which is not the steady state.

---

## Q5 — **[F6]** Root-cause mechanism: what is proven and what is not

Rev 1 asserted an "import-hole baked in at build time 2026-08-09". **That is
disproven, and the replacement claim is deliberately weaker.**

### Proven

1. **The archive was short at signing time.** Manifest entries match disk
   byte-for-byte on T1/T2/T5 and the master tree (Q1a/Q2), and the manifest's
   own recorded sizes are the short ones.
2. **The 2026-08-09 event did not import any data.** The variant-A run was a
   hardlink-stage + cutover of an *existing* T1 tree:
   `stage_receipt.json` (2026-08-09T05:56:12Z) records
   `actions = {HARDLINK_CREATED: 39460, PRIVATE_COPY_CREATED: 3820}` over
   `source_custom = D:\QM\mt5\T1\Bases\Custom` with `source_file_count = 4328`;
   `cutover_receipt.json` (2026-08-09T09:10:39Z) records only
   `LIVE_TO_ROLLBACK` / `STAGE_TO_LIVE` moves. No download, no import step.
   So 2026-08-09 is the **signing and distribution** date, not the origin date.
3. **The hole predates 2026-08-09 by ~3 months.** T1's pre-cutover tree survives
   at `D:\QM\mt5\T1\Bases\Custom.__variant_a_rollback__.custom_history_variant_a_20260809`.
   Read-only stat + sha256 of its `.tkc` files:

   | symbol | 202510 rollback size | rollback mtime | rollback inode | live inode | sha256 == manifest |
   |---|--:|---|---|---|---|
   | AUDCAD.DWX | 1,750,917 | **2026-05-07T04:24:57Z** | 562949953433281 | 844424931335144 | yes |
   | GBPUSD.DWX | 2,091,648 | **2026-05-07T06:07:23Z** | 844424930166229 | 562949954150464 | yes |
   | GBPJPY.DWX | 5,405,743 | **2026-05-07T05:55:16Z** | 844424930165713 | 844424931307403 | yes |
   | GDAXI.DWX (control) | 2,326,780 | 2026-05-07T06:09:37Z | 562949953455711 | 12666373952713932 | yes |

   The rollback copies are **distinct inodes** from the current live files (which
   carry 2026-08-15..18 mtimes from the DL-085 repair ceremony), so this is an
   independent copy, not a hardlink alias — and it was already short.
   An mtime histogram over the whole rollback tick tree shows a bulk write in two
   passes: **2026-04-26/27 (1,127 files) and 2026-05-07 (2,445 files)**, with only
   ~300 later stragglers (2026-05-08/09, 05-15/16, 07-18, 08-06/08/09).
   AUDCAD's entire 2025-01 .. 2026-04 monthly set carries
   mtime 2026-05-07 — one import pass, in which 202510 was already 1.75 MB while
   202509 was 7.05 MB.

   **So the gap entered T1's archive at or before the 2026-05-07 bulk history
   write — five months after the missing window closed, and three months before
   the manifest was signed.**

### NOT proven — explicitly UNDETERMINED

Whether the upstream cause is (a) a defect in whatever tool/procedure performed
the 2026-04/05 bulk history write, or (b) a genuine Darwinex/DWX broker-side
data hole for 2025-10-09..2025-11-03 that the import faithfully reproduced,
**cannot be decided from what is readable here.** What was looked for and not
found:

- `D:/QM/strategy_farm/state/custom_history_repairs.jsonl` — contains only
  DL-085 `MANIFEST_ARCHIVE_FILE_MISSING` repair entries from 2026-08-14..18;
  **zero entries dated 2026-08-09 or earlier**, nothing about the 2026-04/05
  import.
- `D:/QM/strategy_farm/artifacts/ops/custom_history_copy_on_claim/` — 27,777
  receipts, but the **oldest is 2026-08-09T18:55Z**, i.e. all are post-cutover.
  They record copying the archive into terminal-private space, not importing it
  from the broker. **No copy-on-claim receipt for the 2026-08-09 build or for the
  2026-04/05 import exists.**
- The variant-A artefact directory contains staging/ACL/audit/cutover receipts
  only — no import or download log.
- `tools/strategy_farm/custom_history_*.py` are archive *management* tools
  (contract/master/migration/gate/lease/copy-on-claim); none of them downloads
  broker history. No broker-history import tool with a receipt trail was found
  in the repo.

**Therefore the claim in this document is limited to: the archive was already
short when T1's tick tree was bulk-written on 2026-04-26/2026-05-07, and it was
signed short on 2026-08-09. The upstream mechanism (import-tool defect vs
broker-side data gap) is UNDETERMINED.** Deciding it requires either a fresh
DWX-side history pull for that window on a controlled terminal (would show
whether the broker still serves those ticks) or an import log that does not
appear to exist. Neither is in scope for a read-only session.

Note also that the F5 reconciliation already has Dukascopy M1 for the same
window (`p3_symbol_outcomes.csv` shows e.g. AUDCAD `dukascopy_m1_bars=184,250`
vs `dwx_m1_bars=155,802`), i.e. an independent third-party source *does* have
data across the gap. That makes (a) more likely than (b) but does not prove it:
Darwinex could have had a genuine feed outage that Dukascopy did not.

---

## Q6 — Repair proposal (proposal only; nothing executed)

**Why the cheap repair does not work:** the hole is in the signed source, and the
manifest, all T1-T10 archives, the DL-085 master tree and the pre-cutover
rollback tree are byte-identical short copies. `custom_history_master.py`
(repair-first restore) and any re-verify-against-manifest step therefore
**cannot** fill the gap — they only guarantee the terminals equal the (short)
signed state. New tick data must be sourced.

**Scope of missing data:** month **202510** (plus the 2025-11-01/02 sliver in
**202511**) for the **28 FX-pair `.DWX` symbols** — note 28, not rev 1's 27.
Index/metal/energy symbols are unaffected.

**Two governed paths already exist (no new tool needed):**

1. **DWX-native re-download + re-sign (authoritative).** In a controlled
   terminal, re-pull Darwinex `.DWX` broker history for the 28 FX symbols over
   2025-10..2025-11, then rebuild and OWNER-re-sign:
   - `tools/strategy_farm/custom_history_contract.py` — rebuild/validate the
     content-addressed manifest from the refreshed Custom tree
   - `tools/strategy_farm/custom_history_master.py` — rebuild the master tree
   - `tools/strategy_farm/custom_history_migration.py --execute` — OWNER-gated
     staging/cutover/activation to T1-T10 (dry-run by default). **ROT** — touches
     the signed archive; OWNER sign-off mandatory.

   This path has a second payoff: it also **settles Q5's open mechanism
   question**. If the re-pull returns the missing ticks, the 2026-04/05 import
   was defective; if it comes back equally empty, it is a broker-side hole.

2. **Dukascopy backfill/splice.** `tools/dukascopy/download_bi5.py` ->
   `convert_to_import.py` -> `reconcile_overlap.py` produce reconciled M1 for
   the window. **Currently not authorized** — `production_splice_authorized=false`
   everywhere as of the r2 ticket (confirmed in
   `p3/AUDCAD_DWX_reconciliation.json`), and the r2 reconciliation
   `DEFER_NO_SPLICE`d every symbol on session-coverage/DST checks. This path
   needs the splice-authorization work item to land first.

**Recommended: path 1**, with path 2 as cross-check only.

**Cost:**
- Data re-pull + manifest/master rebuild + cutover: bounded by I/O, not
  backtesting — 28 symbols x ~2 months x ~7 MB ~ 0.4 GB per terminal; a
  10-terminal cutover is minutes of copy plus the interactive DWX download
  session. Order **< 1 terminal-hour** of factory time. *(This figure is an
  I/O-volume argument, not a measurement — the 2026-08-09 stage_receipt shows the
  equivalent full-tree operation was hardlink-based and completed inside the
  05:56Z..09:10Z window, but that covered 4,328 files, not 56.)*
- Evidence-integrity re-run: **scope C 54.6 / scope B 77.1 / scope A 116.9
  terminal-hours**, i.e. **11.1 / 15.7 / 23.7 wall-clock hours** at the measured
  mean concurrency of 4.92 (Q4).

**Recommended sequencing:** OWNER decides path 1 vs 2 and re-run scope. Given the
materiality split (Q3e), a defensible minimum is scope C (the 168 PASS-like gate
rows, ~11 wall-clock hours); the 807 pure-2025 census cells at ~7 % materiality
are the population most likely to have actually moved, and are the natural
second tranche.

---

## Exact commands run (all read-only)

```
cd C:/QM/repo

# Q1/Q2 — on-disk vs signed manifest, T1/T2/T5
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/compare_tkc_vs_manifest.py
# -> T1/T2/T5 each {INTACT:74, UNVERIFIABLE:4}

# F4 — cohort membership at 0.35/0.40/0.50 for all 37 manifest tick symbols
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/f4_cohort_threshold_matrix.py
# -> 28 FX pairs 0.2157..0.4087; 9 non-FX 1.1725..2.0808; GBPJPY flips at 0.40

# F7 — chunk tick counts + per-day M1 bar counts
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/f7_gap_window_tick_counts.py
# -> 21/27 export-COMPLETE symbols lose 84.0-94.5% of gap-window weekday bars

# F1/F3/F5 — exposure, relevance classes, per-row materiality
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/q3_affected_work_items.py
# -> 5,911 overlapping; 2,199 cohort-exposed; impact set 1,047 (238 gates)

# F2 — measured runtimes, measured concurrency, priced re-run
python docs/ops/evidence/2026-09-15_t1_archive_gap_oct2025/f2_rerun_cost_model.py
# -> peak 10 / mean 4.92 concurrent; scope A/B/C = 116.9 / 77.1 / 54.6 terminal-h

# schema inspection
sqlite3 'file:D:/QM/strategy_farm/state/farm_state.sqlite?mode=ro' '.schema work_items'

# slot census
python tools/strategy_farm/farmctl.py mt5-slots
```

Ad-hoc read-only probes whose results are quoted above but which are not worth
keeping as scripts: `os.stat` over the rollback tick tree (inode / mtime / size,
Q5.3), `sqlite3` aggregate of `terminal`/`report_root`/`claimed_at_iso` presence
by verdict (Q3c table), and directory listings of
`custom_history_copy_on_claim/` and the variant-A artefact directory (Q5 "not
found" list).

## What could NOT be verified read-only in this session

1. **The upstream mechanism of the gap** (import-tool defect vs Darwinex-side
   data hole) — see Q5. Needs a fresh DWX history pull on a controlled terminal.
2. **Count-level confirmation for 7 of the 28 FX pairs** (`EURAUD, EURCHF,
   EURJPY, EURUSD, GBPAUD, GBPJPY, USDJPY`) — the available M1 export is itself
   `SHORT_READ` for them. Their cohort membership rests on manifest file size
   only. Re-running the export after the SHORT_READ defect is fixed would close
   this.
3. **Whether any of the 165 PASS gate verdicts would actually flip.** Materiality
   bounds the missing *data*, not the verdict delta. Only a re-run decides that.
4. **Provenance of the 2026-04-26/27 + 2026-05-07 bulk history write** — no
   receipt, log or ticket for it was found; the 2026-05-07 date comes from
   filesystem mtimes on the surviving rollback tree, which is weaker evidence
   than a signed receipt and could in principle reflect a copy rather than the
   original import.
