# Dukascopy lane P3 follow-up: reconciler boundary defect + export short-read root cause

Follow-up task: `ca955879-fd90-4889-9f72-187dfd4e3522` (parent `60174747-2b7b-4326-88fe-3f3e1adc3ba3`)

Disposition: **REVIEW — both defects fixed and tested; no T1 probe rerun performed;
no archive/manifest/production-splice write.**

Commit under review: this evidence is written against
`agents/board-advisor` HEAD `5b18d2da3cc04f1983d3838ce0a4a90c013baae8`, plus the two
uncommitted working-tree changes listed below (to be committed alongside this file).

## Scope discipline

Per the ticket's hard limits, all code changes stay inside `tools/dukascopy/` and its
tests. The governed T1 export script
(`framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5` and its Python
wrapper `dwx_m1_overlap_export.py`) was **read only** — root-caused, not edited. Fixing
it would require a MetaEditor recompile and a new T1 export run, which is explicitly
deferred to a separate governed work item. No terminal was started, no T1/T_Live state
was touched, and no fixed reconciliation threshold (1.5x spread p95, 99% bilateral
coverage, DST 0 s) was changed.

## (a) Reconciler end-boundary contract — fixed

`tools/dukascopy/reconcile_overlap.py::reconcile_symbol` compared the last observed M1
bar directly against `REQUIRED_OVERLAP_END` (2026-04-01T00:00:00Z). The required window
is the governed export's own half-open interval `[START, END)`; an M1 bar is keyed by
its open time, so a fully complete series' last bar opens at `END - 60s`
(2026-03-31T23:59:00Z), never at `END` itself. The old check therefore rejected every
bilaterally complete symbol by exactly one bar — this is what produced the prior 0/37
`required_overlap_window=FAIL` result across the board (see
`docs/ops/evidence/2026-09-15_dukascopy_p3_completion/README.md`, item 1).

Fix: `overlap_window_complete` now compares against
`REQUIRED_OVERLAP_END - M1_BAR_SECONDS` (new named constant, `M1_BAR_SECONDS = 60`).
No other threshold changed.

New test: `tools/dukascopy/tests/test_dukascopy_backfill.py::
test_required_overlap_window_is_half_open_at_the_required_end` builds a synthetic
complete pair whose last bar is exactly `END - 60s` and asserts
`checks["required_overlap_window"] is True` (previously `False` under the old code —
verified by reverting the one-line fix locally and re-running the test, which fails as
expected). A second case in the same test shifts the DWX file's last bar back one more
minute (a genuinely short file) and asserts the check still correctly fails, with
`overlap_last_broker_epoch` reported.

## (c) Export-receipt hardening — implemented inside the reconciler

The governed T1 export receipt (`export_receipt.json` /
`dwx_m1_manifest.json`, produced by `dwx_m1_overlap_export.py`, outside this ticket's
file scope) classifies a symbol call as successful whenever `written_rows > 0`
(`QM_DWX_M1_Overlap_Export.mq5::ExportOne`, read only, unmodified this ticket). That
receipt cannot be hardened without touching `framework/scripts/mt5_diagnostics/` and
recompiling on T1, both out of scope here. Instead, the hardening is implemented at the
one place this ticket is allowed to touch: `reconcile_overlap.py`'s own per-symbol
verdict, which is the artifact any future splice/gate decision actually reads.

Added `SHORT_READ_COVERAGE_RATIO = 0.5` and a new `SHORT_READ` status, distinct from
`PASS`/`FAIL`: a symbol call is `SHORT_READ` whenever `dukascopy_coverage` (the fraction
of Dukascopy-side minutes also present in the DWX file — i.e. how much of the expected
window was actually returned) falls below 0.5, regardless of how high `dwx_coverage`
looks. `SHORT_READ` is never `PASS` (it's gated the same as `FAIL` by `all(checks.values())`,
and `session_coverage` already required >=99%), so no severity of short read can pass
under any of today's fixed thresholds — the change is a strictly additive
classification layer, not a threshold change. `short_read_threshold` is echoed in every
symbol's output for traceability.

Threshold justification (0.5): the fixed-window reconciliation observed exactly two
populations on 2026-09-13 data — 27 symbols at 83.8%-98.5% `dukascopy_coverage`
(ordinary DWX/Dukascopy session-accounting differences, not a defect; see completion
README item 2) and 10 symbols at 0.03%-2.3% (catastrophic). 0.5 sits in the empty gap
between them and does not need to be tuned close to either population.

New test:
`test_short_read_status_is_distinct_from_an_ordinary_coverage_failure` reproduces the
real pattern (`dwx_coverage` ~100% of a tiny scattered sample, `dukascopy_coverage` a
fraction of a percent) and asserts `status == "SHORT_READ"`.

**Known limitation, stated rather than silently swallowed:** AUDCAD's real defect (see
below) aggregates to 84.48% `dukascopy_coverage` — inside the "ordinary" 83.8%-98.5%
band, not below the 0.5 `SHORT_READ` line. A single coverage-ratio threshold cannot
separate AUDCAD's genuine ~25-day short-read gap from the other 26 symbols' legitimate
session-accounting shortfall; only the direct timestamp-gap inspection performed below
distinguishes them. AUDCAD is correctly still `FAIL`, not silently `PASS`, but it is not
labeled `SHORT_READ` by the reconciler today. Recommendation for whoever takes the next
work item: a gap-based check (longest silent interval between consecutive DWX minutes)
would catch this class without touching the coverage threshold; not implemented here
because it is a new detection lever, not the boundary/classification fix this ticket
asked for.

## Verification

```text
python -m pytest -q tools/dukascopy/tests/test_dukascopy_backfill.py
21 passed

python -m pytest -q tools/dukascopy/tests/
34 passed

python -m compileall -q tools/dukascopy
PASS

python tools/dukascopy/reconcile_overlap.py --jobs D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_jobs.json --instrument-metadata C:/QM/repo/docs/ops/evidence/2026-09-12_dukascopy_p3_redo/dukascopy_price_scale.csv --out D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_defects_fixed_rerun
exit 1; status FAIL; symbols 37 (re-run of the existing 2026-09-13 export CSVs through
the fixed reconciler -- NOT a new T1 probe; reuses D:/QM/reports/dukascopy/
reconciliation_inputs/dwx_m1/20260913_114500 unchanged)
```

Result of the fixed-reconciler re-run against the unchanged 2026-09-13 export CSVs:
27 `FAIL`, 10 `SHORT_READ`, 0 `PASS` (still fail-closed, as expected — the export data
itself was not touched). Compared to the pre-fix run:

- `required_overlap_window` now reports `True` for every one of the 27 non-sparse,
  non-session-limited FX/CFD symbols (previously `False` on all of them by the 60 s
  artifact). It correctly stays `False` for `GDAXI.DWX` and `UK100.DWX` (real
  session-close shortfalls of 14,520 s and 120 s respectively — unaffected by the fix)
  and correctly becomes `True` for `AUDCAD.DWX` once the artifact is removed.
- The 10 catastrophically sparse symbols are now labeled `SHORT_READ` instead of a
  generic `FAIL`, each carrying `short_read_threshold: 0.5` and their true
  `dukascopy_coverage` (0.03%-2.3%) in the output record.

Reconciliation output SHA-256:

| Artifact | SHA-256 |
|---|---|
| `tools/dukascopy/reconcile_overlap.py` (fixed) | `cce53acc89e6470fefba7c6477a1f28bf85ffcf41b2bfa590d98d5c2fc720b59` |
| `p3_defects_fixed_rerun/reconciliation_summary.json` | `9884a4c9ba57c35ebdc12bd1e3d42aa2ee94a737336532ba11a35442c281a9f5` |
| `p3_defects_fixed_rerun/reconciliation_summary.csv` | `095ef8f8f1dc3c104df12c096656e22c18cabed5ab646aea32b38ee2dd02dde7` |

`D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_defects_fixed_rerun` is a
new subdirectory of the existing, already-inventoried `60174747` scratch root (per the
completion README, this root's presence is already accounted for); it adds
reconciliation-only output (`production_splice_authorized: false` on every row) and
writes nothing under `D:/QM/reports/dukascopy/conversion` or any archive/manifest path.

## (b) Export root cause: sparse/truncated DWX for 11 symbols

**Ruled out, with evidence:** the 10 symbols and AUDCAD were never imported into T1's
local custom-symbol tick store. `D:/QM/mt5/T1/bases/Custom/ticks/<SYMBOL>.DWX/` holds a
`.tkc` file for every month `201710`-`202609` for all four symbols spot-checked
(`EURUSD`, `GBPJPY`, `AUDCAD`, and the non-sparse `GBPUSD` control), and the October
2025-March 2026 files are multi-megabyte for all of them (1.6-17.8 MB per symbol-month;
e.g. `EURUSD.DWX/202601.tkc` = 5.74 MB, comparable in order of magnitude to
`GBPUSD.DWX/202601.tkc` = 8.44 MB). The on-disk archive is not empty or missing for
these symbols.

**Established, with evidence, from the exported CSVs themselves**
(`D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260913_114500/dwx_m1/*.csv`,
read only, not modified):

| Symbol | DWX bars | Dukascopy-side bars in window | dukascopy_coverage | Distinct multi-day gaps (>3d) | First / last observed minute |
|---|---:|---:|---:|---:|---|
| EURAUD.DWX | 83 | 181,667 | 0.046% | 22 | 2025-10-01T07:32Z / 2026-03-30T13:02Z |
| EURCHF.DWX | 62 | 181,617 | 0.034% | 24 | 2025-10-02T01:43Z / 2026-03-31T14:58Z |
| EURJPY.DWX | 85 | 181,381 | 0.047% | 24 | 2025-10-01T14:28Z / 2026-03-30T15:05Z |
| EURUSD.DWX | 61 | 173,596 | 0.035% | 21 | 2025-10-07T00:40Z / 2026-03-26T19:58Z |
| GBPAUD.DWX | 116 | 179,516 | 0.065% | 22 | 2025-10-03T04:50Z / 2026-03-31T12:10Z |
| GBPJPY.DWX | 108 | 182,015 | 0.059% | 25 | 2025-10-01T23:25Z / 2026-03-31T11:58Z |
| NDX.DWX | 117 | 166,143 | 0.070% | 25 | 2025-10-03T00:06Z / 2026-03-31T15:15Z |
| USDJPY.DWX | 83 | 179,463 | 0.046% | 27 | 2025-10-03T18:30Z / 2026-03-31T12:40Z |
| XAUUSD.DWX | 126 | 173,451 | 0.073% | 24 | 2025-10-02T08:55Z / 2026-03-31T16:12Z |
| XNGUSD.DWX | 2,607 | 109,621 | 2.275% | 2 | 2025-11-26T18:06Z / 2026-03-31T23:58Z |
| AUDCAD.DWX | 155,802 | 184,250 | 84.480% | 2 | 2025-10-01T00:00Z / 2026-03-31T23:59Z |

For the 10 catastrophically sparse symbols, the surviving rows are not a truncated
prefix/suffix — they are short (1-5 minute) contiguous bursts scattered across the full
six months, separated by 20-27 multi-day silences. The gap count (20-27) lands close to
the number of `InpChunkDays=7` weekly chunks in the six-month window (~26), i.e. most
individual 7-day `CopyTicksRange` chunks returned close to zero ticks for these symbols,
with only an occasional chunk returning a real few-minute sample.

`AUDCAD.DWX` is structurally different and was directly verified by reading its raw
export CSV: it is fully dense (one row per minute, matching `GBPUSD`-class symbols) from
2025-10-01T00:00Z through 2025-10-08T23:59Z, then has **one** gap of 24.9 days
(2025-10-08T23:59Z -> 2025-11-02T22:05Z), then resumes fully dense through
2026-03-31T23:59Z (one further, unremarkable ~4.2-day gap around 2025-12-17 to
2025-12-21, consistent with a normal weekend/holiday closure). This is the same defect
class as the 10 sparse symbols (a handful of consecutive weekly chunks returning near-
zero ticks) at much lower severity — 3-4 bad chunks out of ~26, not 20-27 out of 26 —
which is exactly why its aggregate coverage (84.48%) lands inside the "ordinary" 27-symbol
band instead of the sparse-symbol band, and is not caught by the `SHORT_READ` classifier
above.

**Definite code-level defect (read only, proven by source inspection, not by rerunning
anything):** in `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5`,
`CopyChunk` only retries when `CopyTicksRange` returns a negative count
(`copied>=0 && copy_error!=ERR_HISTORY_TIMEOUT` returns immediately). A chunk that
returns `copied=0` — a legitimate return value both when a symbol genuinely traded zero
ticks in that 7-day window and, indistinguishably to this code, when the terminal's tick
database has not finished serving that symbol/period yet — is accepted immediately with
no retry and no record of the shortfall. `ExportOne` then reports success for the whole
symbol whenever `written_rows > 0` anywhere across all ~26 chunks, with no comparison
against how many minutes the window should contain. This is sufficient by itself to
explain why the completion marker read `successes=37 failures=0` and the export receipt
classified all 37 symbol calls `PASS`/`COMPLETE` despite these 11 near-total shortfalls:
the receipt's only bar for "success" was `>0 rows`, and it was met.

**UNKNOWN, stated rather than guessed:** the exact internal MT5 reason a specific
7-day `CopyTicksRange` chunk returns near-zero ticks for one symbol while the identical
call shape succeeds fully for 27 others in the same ~45-second run, given that the
on-disk `.tkc` archive for the affected symbols is not empty. No terminal journal entry
for this run documents a `TICK_REFUSED`/`COPY_TICKS_RANGE_FAIL`/`SYMBOL_SELECT_FAIL`
line for any symbol (`D:/QM/mt5/T1/MQL5/logs/20260913.log` and
`D:/QM/mt5/T1/logs/20260913.log` were read in full for the 13:52:16-14:01:19 local
(11:52-11:56 UTC on the wall clock, terminal restarted again for the next queued
backtest at 14:01:19 local) window covering this export's `pid=17696` process; only the
terminal-level `script ... loaded successfully` line was found, no per-symbol
`Print()` output from `QM_DWX_M1_Overlap_Export.mq5` survived in either log for this
run). Binding the terminal-internal cause further would require instrumenting a new T1
run, which this ticket's hard limits explicitly forbid ("no T1 probe rerun in this
ticket"). This class of defect has a documented precedent:
`lessons-learned/evidence/2026-04-27_qua93_xauusd_chunked_probe.json` and the sibling
QUA-93/94/95 records (XAUUSD/XTIUSD/WS30/XNGUSD, 2026-04-27) show `CopyTicksRange`/
`CopyRates` returning 0 despite a matching `tick_head_expected`, resolved only after a
"runtime recovery" per `QUA-95_UNBLOCK_READINESS_SUMMARY_2026-04-27.md`. That precedent
is consistent with, but does not prove, the same mechanism recurring on 2026-09-13; it
is offered as context for the next work item, not as a bound cause for this one.

## Bound inputs (unchanged from the parent task)

| Input | Binding |
|---|---|
| Governed DWX export | `D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260913_114500`; work item `030e8488-5372-439e-be03-0430748cf83b`; receipt SHA-256 `996553f4c4274a15527ee2fddc049a72f3440578b4ad9ab3dacd8c79c2cb14a9` |
| Dukascopy P1 manifest | SHA-256 `a7d9fe65494f126f7cf468bb7158396469801f52a95db2868c5b21afb1dade42` |
| Provider-scale receipt | SHA-256 `2dbf6f6662243fa8abd2982543a092a6765c8f62358f9d90270d46efc3299db1` |
| Fixed UTC interval | `[2025-10-01T00:00:00Z, 2026-04-01T00:00:00Z)` |

## What was not done (by design)

- No T1 probe rerun. The 2026-09-13 export CSVs were only re-read (never re-fetched)
  through the fixed reconciler. The next governed work item can now request a real T1
  rerun without guaranteeing a fail-closed result on the boundary artifact alone.
- No change to `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5` or its
  Python wrapper — out of this ticket's file scope.
- No archive write, no production splice, no manifest update.
  `archive_write_authorized=false` and `production_splice_authorized=false` on every
  new record produced here.
- No fixed reconciliation threshold changed (1.5x spread p95, 99% bilateral coverage,
  DST 0 s all untouched).

RESULT task=ca955879-fd90-4889-9f72-187dfd4e3522 parent=60174747
boundary_fix=DONE+TESTED short_read_hardening=DONE+TESTED
root_cause=10_sparse_UNKNOWN_MECHANISM_evidence_bound+AUDCAD_25day_gap_evidence_bound
tests="34 passed" compileall=PASS t1_probe_rerun=NONE
archive_write_authorized=false production_splice_authorized=false
