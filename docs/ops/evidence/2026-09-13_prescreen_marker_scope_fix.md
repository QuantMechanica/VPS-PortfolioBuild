# PRESCREEN first-claim proof — real-ticks marker current-run scoping fix

- Ticket: router `24df7ddd` (PRESCREEN first-claim proof failed)
- Date: 2026-09-13
- Scope: `framework/scripts/run_smoke.ps1` (real-ticks marker scan only) + test + this doc
- Class: fail-closed evidence fix. No gate threshold / criterion / verdict change.

## Root cause

Work item `2a897e8e-35d4-5a4c-bc07-0affa5c9de30` (QM5_41405
`balke-clock-audit-opt`, USDJPY.DWX, H1, 2019.01.01–2019.12.31, **Model=1
PRESCREEN**, T2, run `20260913_142412`) ended `result=PASS` with
`evidence_class=PRESCREEN` and `model=1`, yet its
`summary.json` carried `model4_log_marker_detected=true` and
`runs[0].real_ticks_marker=true`. `farmctl._derive_prescreen_verdict_from_summary`
correctly treats a real-tick marker on a Model-1 PRESCREEN cell as impossible by
construction and returned **INFRA_FAIL `PRESCREEN_EVIDENCE_CLASS_MISMATCH`**.

The false marker came from `run_smoke.ps1`. The real-ticks scan
(`Select-String -Pattern "generating based on real ticks"`) ran over the **full
copied daily tester journal**. MetaTester reuses one daily journal per terminal
agent, so the copied file
(`…/20260913_142412/raw/run_01/20260913.log`, 4.79 MB, UTF-16LE) contained
markers from **earlier Model=4 runs of other cells on T2 that day**. Verified in
the copied log:

- `generating based on real ticks` present **10×** (journal lines 25 … 17695).
- Earlier Model=4 start markers at broker times 12:31:50, 12:36:24, 12:48:00,
  13:02:09, 13:06:50, 13:20:09 (QM5_41398 balke-pattern-repair), 13:20 (QM5_2132),
  13:29:29, 13:51:25, 15:12:55 (QM5_20250), 16:19:19 (QM5_41398 2025).
- The **current run** start marker
  (`USDJPY.DWX,H1: testing of Experts\QM\QM5_41405_balke-clock-audit-opt.ex5 from
  2019.01.01 00:00 to 2019.12.31 00:00 started with inputs:`) is at **line ~20040**
  (16:24:20). **No** `generating based on real ticks` line appears after it.

The current-run scoping helper `Get-TesterLogCurrentRunText` (last "started with
inputs" marker) was applied only to the 800-line tail, never to the full-log scan,
so the unscoped scan attributed the earlier cells' markers to the PRESCREEN cell.

## Change (behavioural)

`framework/scripts/run_smoke.ps1`:

1. New function `Get-TesterLogRealTicksMarker`. It reads the **full** copied
   tester log (BOM/UTF-16 aware, same stream/BOM detection as
   `Get-TesterLogTailText`, 256 MB safety cap), scopes it to the current run with
   `Get-TesterLogCurrentRunText` using the **same** Expert/Symbol/FromDate/ToDate
   as the existing tail call, and returns `$true` **only** if the marker appears
   inside that current-run section.
2. Fallback when the current-run start marker cannot be located (empty scoped
   section): **REAL_TICKS** (Model=4) keeps the legacy full-file `Select-String`
   scan, so a valid Model=4 run is never flipped to `NO_REAL_TICKS` by a
   log-format surprise; **PRESCREEN** (Model=1) never accepts an unscoped
   full-file hit and fails closed (`$false`).
3. Call site (former lines ~3603–3606) now calls the helper with
   `-RequiresRealTicksMarker $requiresRealTicksMarker`
   (`$EvidenceClass -ceq "REAL_TICKS"`, defined at line ~84). The existing tail
   regex fallback and `Test-ReportShowsRealTicks` HTML fallback are unchanged and
   in the same order. No new parameters were invented.

Net effect: the incident PRESCREEN cell now yields `real_ticks_marker=false`, so
the derive produces the intended `PRESCREEN_MEASURED` verdict instead of
`INFRA_FAIL PRESCREEN_EVIDENCE_CLASS_MISMATCH`.

## Why the Model=4 proof is not weakened

For REAL_TICKS the scoped scan is **strictly stronger** than the old full-file
scan: when the current-run start marker is found, scoping can only *remove*
cross-run false positives, never a genuine current-run marker (the marker sits
near the START of a large real-tick run, right after synchronization, and is
inside the scoped section). When the start marker cannot be located, REAL_TICKS
falls back to the exact legacy full-file scan, so no valid Model=4 run can be
flipped to `NO_REAL_TICKS`. `farmctl.py` / `terminal_worker.py` were not touched
(their derive logic is correct and needs an orchestrator reload).

## Tests

- `tools/strategy_farm/tests/test_run_smoke_real_ticks_marker_scope.py` (new):
  slices the two PS function bodies into a harness (style of
  `test_buildcheck_predicate_fix.py`), UTF-16LE+BOM fixtures:
  - (a) older run with marker + current run without → **False** for PRESCREEN and REAL_TICKS.
  - (b) marker inside the current-run section → **True** for both.
  - (c) no start marker, marker present in file → REAL_TICKS legacy full-scan **True**, PRESCREEN **False**.
  - (d) the real copied incident log → **False** for both (skips if aged out).
  - Result: `2 passed`.
- Existing PRESCREEN-derive coverage
  `tools/strategy_farm/tests/test_opt_census_dispatch.py`
  (contains `_derive_prescreen_verdict_from_summary`): `50 passed`.
- Parse check:
  `powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -Raw framework/scripts/run_smoke.ps1)) | Out-Null"` → `PARSE_OK`.

## Rollback

`git revert` of the `run_smoke.ps1` hunk (the new `Get-TesterLogRealTicksMarker`
function plus the call-site change), which restores the unscoped full-file scan.
Blast radius: real-ticks marker evidence in future smoke runs only; no state or
verdict already recorded is mutated by the revert.

## Follow-up (orchestrator)

Append-only rerun of the affected PRESCREEN cell so the corrected scan produces a
clean verdict, preserving the old row as evidence:

```
farmctl enqueue-backtest --append-only-rerun-of 2a897e8e-35d4-5a4c-bc07-0affa5c9de30
```

`run_smoke.ps1` executes fresh per backtest, so the rerun picks up the fix with no
reload; `farmctl.py`/`terminal_worker.py` still require the standard orchestrator
reload before their (already-correct) derive path runs against new summaries.
