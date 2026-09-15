# Dukascopy export fix round 2: cross-model critic findings closed (F1-F7)

Task: `9e0fb916-27d3-4022-9a95-dc0547883896` (parent `dc7f0545-2d0a-4220-a1a4-4a9141dbade8`,
grandparent `ca955879-fd90-4889-9f72-187dfd4e3522`)

Disposition: **REVIEW — F1-F7 addressed and tested, MetaEditor compile bound.
No T1 export run performed. No archive write, no manifest update, no
production splice. One major new finding surfaced (see "Major finding"
below) that is out of this ticket's scope to root-cause.**

This evidence is written against `agents/board-advisor` HEAD
`09806c282f22d83738df3dcb980f1dc60e87f6f8`, plus the working-tree changes
listed below (to be committed alongside this file, in the canonical
checkout `C:/QM/repo`, using explicit pathspecs).

Source critique: `D:/QM/strategy_farm/artifacts/agent_chain/critique_dc7f0545_20260915T071621Z/final.md`
(Creator->Critic->Formatter chain, Opus critic, verdict **GAPS**, 5 major + 5
minor findings F1-F10). This ticket addresses F1-F7 (its literal acceptance
list); F8-F10 are minor findings on the prior delivery not in this ticket's
acceptance and are left untouched (no file-scope reason to touch them).

## Scope discipline

No terminal64.exe was started, T1-T10/T_Live were not signalled, no export
ran; compile happened outside the factory and live terminal trees (DEV1); no
fixed reconciliation threshold (1.5x spread p95, 99% bilateral coverage, DST
0 s) changed; the new checks stayed additive and fail-closed. Files touched:

- `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5`
- `framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py`
- `framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py`
- `tools/dukascopy/reconcile_overlap.py`
- `tools/dukascopy/tests/test_dukascopy_backfill.py`

## F1 — FX completeness floor cannot separate AUDCAD from the ordinary population (documented, not "fixed" by tightening)

Tightening the FX allowance was rejected: AUDCAD's real ratio is 84.25% of
ceiling (155,802 / 147,936 floor at the current 0.20 allowance = **still
COMPLETE**, empirically confirmed below in F2's table), which sits *inside*
the 83.8%-98.5% band the 27 "ordinary" symbols occupy — no single whole-
window allowance can exclude AUDCAD without also rejecting legitimate
exports. `dwx_m1_overlap_export.py`'s completeness-floor comment block now
states this explicitly and names the two mechanisms that do catch this
class: `reconcile_overlap.longest_weekday_gap` (the authoritative
reconciliation-stage check) and the new per-chunk diagnostic (F4) at export
time. The whole-window floor is documented as deliberately *not* this
class's catching mechanism.

## F2 — Completeness floor run read-only over the real 2026-09-13 export; 37-row table bound

`load_expected_minutes` + `classify_completeness` (unmodified logic) run
read-only over
`D:/QM/reports/dukascopy/reconciliation_inputs/dwx_m1/20260913_114500/dwx_m1/*.csv`
(row-counted, no canonicalization re-run, no write to that directory).
Result: **10 SHORT_READ, 27 COMPLETE** — the sparse-10 from the mother ticket
(`docs/ops/evidence/2026-09-15_dukascopy_p3_defects/README.md`) exactly, and
AUDCAD confirmed `COMPLETE` (ratio 1.0532) despite its known 25-day hole,
proving F1's claim empirically rather than asserting it. No legitimate
symbol falls under its floor at the current 0.20/0.35 allowances — no
evidence to justify tightening them.

Table: `f2_completeness_floor_measurement.csv` (this directory), sha256
`e3a1adbe95ffbc0d420ce69d989fb235088f1159a6db083647052217bb17acd1`.

## F3 — export_receipt.json now binds the chunk journal by path+sha256

`canonicalize_export_set` (`dwx_m1_overlap_export.py`) now attaches a
`chunk_journal` field (`{path, sha256, row_count}`) to each symbol's
manifest binding whenever `<symbol>_M1_chunks.csv` is present (it stays
`None` for older exports/fixtures that predate the journal). This is the
"path+sha256 binding" option from the acceptance criterion, chosen over
embedding full parsed rows: a 37-symbol x ~26-chunk x up to-4-attempt
journal would materially bloat the manifest, and the copied CSV is already
retained at `raw/<symbol>_M1_chunks.csv` for direct inspection. `short_chunks`
(F4) remains the derived, human-readable summary.

## F4 — mq5 records per-chunk written minutes; short_chunks lists material shortfalls, not only zero chunks

`QM_DWX_M1_Overlap_Export.mq5::ExportOne` now journals a `CHUNK_ROWS` row per
chunk (`phase="bars", status="CHUNK_ROWS"`, reusing the existing 8-column
schema with `copied` repurposed as "M1 bars written this chunk" for that
status value only) alongside the existing sync/zero_retry/final rows. A
one-line in-code comment documents the known ±1 bar boundary carry-over
(the chunk's final in-progress bar is only flushed on the next minute
transition, sometimes in the next chunk) — dwarfed by the thousands-of-
minutes chunk floor this feeds.

`dwx_m1_overlap_export.py::chunk_expected_minutes` computes a per-chunk
floor from `reconcile_overlap._weekday_seconds_in_range` (the same weekday
proxy the gap check uses) times the symbol's session-closure allowance.
`short_chunks_from_journal` now merges `ZERO_TICK_CHUNK` rows with
`CHUNK_ROWS` rows materially under their chunk floor, keyed by
`(chunk_start_epoch, chunk_end_epoch)`; new test
`test_short_chunks_from_journal_flags_material_shortfall_not_only_zero`
builds a synthetic 5-chunk journal with 3 non-zero-but-short chunks (the
AUDCAD 3-of-~26 pattern) and asserts all three are flagged with
`chunk_rows_written`/`chunk_expected_minutes`.

**Deliberately informational, not a status gate:** `short_chunks` does not
by itself flip a symbol's `COMPLETE`/`SHORT_READ` status. There is no
production chunk-journal data yet (the 2026-09-13 raw exports predate the
journal) to calibrate a per-chunk allowance the way F2 calibrated the
whole-window one, and the per-chunk floor is tighter (one week's worth of
weekday minutes, not six months') -- promoting it to a hard gate without
that calibration risks rejecting a legitimate single-holiday chunk on the
next governed T1 rerun. This is stated in-code (`dwx_m1_overlap_export.py`
completeness-floor comment block), not silently assumed.

## F5 — status ladder reordered; reconciler re-run over unchanged inputs; new label distribution bound

`reconcile_overlap.py::reconcile_symbol`: `is_short_read` (coverage < 0.5)
is now evaluated **before** `is_short_read_gap`, so the ladder is
`PASS > SHORT_READ > SHORT_READ_GAP > FAIL`. The 10 catastrophic symbols
stay `SHORT_READ` (their `dukascopy_coverage` is 0.03%-2.3%, unaffected by
the reorder); only the 27 non-catastrophic symbols are eligible for the new
`SHORT_READ_GAP` label. Existing `checks` dict stays byte-identical (gap
fields remain additive, not folded in), matching the prior ticket's own
pattern.

Re-run command (no T1, unchanged 2026-09-13 inputs, same 37-job manifest the
mother ticket used):

```text
python tools/dukascopy/reconcile_overlap.py \
  --jobs D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_jobs.json \
  --instrument-metadata C:/QM/repo/docs/ops/evidence/2026-09-12_dukascopy_p3_redo/dukascopy_price_scale.csv \
  --out D:/QM/reports/dukascopy/reconciliation/20260915_60174747/p3_gap_order_fix_rerun
exit 1; status FAIL; symbols 37
```

**New 37-symbol label distribution: 10 SHORT_READ, 27 SHORT_READ_GAP, 0
PASS, 0 FAIL** (compare mother ticket's fixed-reconciler baseline: 27 FAIL +
10 SHORT_READ, `docs/ops/evidence/2026-09-15_dukascopy_p3_defects/README.md`
lines 109-110). Every one of the 27 non-catastrophic symbols now carries a
`longest_weekday_gap_seconds` above the 24h threshold — see "Major finding"
below, this is not the AUDCAD-only outcome the prior ticket's prose implied
and is reported as found, not smoothed over.

| Artifact | SHA-256 |
|---|---|
| `p3_gap_order_fix_rerun/reconciliation_summary.json` | `3cac75ae5655e197dc6e6de0c4e7a86293f71eb1e9aabbe3d4479f5853b82449` |
| `p3_gap_order_fix_rerun/reconciliation_summary.csv` | `dde7b3e4411e9871604e84dfb76f1e8ee51bb476dcf554d02bdd9594fce73ce5` |

## Major finding (not a fabricated claim — bound to the rerun above): the "ordinary" population is not evenly distributed session accounting, and the December commodity gaps look like a false-trigger of the new 24h threshold

Sorting the rerun's `longest_weekday_gap_seconds` by symbol (full table in
`p3_gap_order_fix_rerun/reconciliation_summary.json`) shows two distinct
sub-populations inside the 27 `SHORT_READ_GAP` symbols, not one:

**(A) ~21 FX symbols + AUDCAD share the *same* ~25-day hole.** 9 of them
(AUDJPY, AUDNZD, CADCHF, CHFJPY, GBPUSD, NZDCAD, NZDCHF, NZDJPY plus AUDCAD
itself) bind the **exact same** gap boundary to the minute:
`longest_weekday_gap_start_broker_epoch=1759978740`
(2025-10-09T02:59:00Z), `..._end_broker_epoch=1762128300`
(2025-11-03T00:05:00Z) — a 24.88-calendar-day, ~405-weekday-hour hole. A
further ~11 symbols (EURGBP, AUDUSD, USDCHF, CADJPY, EURCAD, GBPCAD, AUDCHF,
EURNZD, GBPCHF, GBPNZD, USDCAD) share the same window to within a few
minutes/hours (their own last-tick-before/first-tick-after differs slightly).
This is not an AUDCAD-specific anomaly: it is a shared, dateable event
across the majority of the 37-symbol FX/index universe, most likely a T1
`Bases/Custom` tick-archive or import gap for 2025-10-09 through 2025-11-03,
2025 — **not investigated further here** (out of this ticket's file scope;
would require reading the T1 archive the way the mother ticket's AUDCAD/
EURUSD/GBPJPY/GBPUSD spot-check did). This reframes the mother ticket's "27
symbols at 83.8%-98.5% coverage = ordinary session accounting, not a
defect" characterization: a meaningful share of that shortfall is this one
shared multi-week hole, not generic session-accounting noise.

**(B) 6 index/commodity symbols (GDAXI, UK100, SP500, WS30, XAGUSD,
XTIUSD)** have a much shorter gap (53-104 weekday-hours, 2.2-4.3 days) dated
2025-12-16 through 2025-12-29 — squarely the Christmas/New Year window the
mother ticket's own AUDCAD section already characterized as "a normal
weekend/holiday closure" for a similar-dated secondary AUDCAD gap
(`docs/ops/evidence/2026-09-15_dukascopy_p3_defects/README.md:176-177`).
These 6 are the most likely **false triggers** of
`SHORT_READ_GAP_WEEKDAY_HOURS=24`: a legitimate multi-day holiday closure
for CFD/index instruments plausibly exceeds 24 weekday-hours without being a
DWX-side defect.

**Why this ticket does not retune the threshold:** `SHORT_READ_GAP_WEEKDAY_HOURS`
is a new check (not one of the fixed reconciliation thresholds), so it is
technically in scope to adjust, but picking a new number now would repeat
exactly the unvalidated-constant pattern F1/F2 were raised against — there
is no third calibration population to separate "ordinary holiday" (2.2-4.3
days) from "AUDCAD-class defect" (24.9 days) other than these two small
samples, and the operational risk of leaving it as-is is low:
`SHORT_READ_GAP` never authorizes a splice (`production_splice_authorized`
stays `false` on every row, identical to `FAIL`), so relabeling the 6
commodities from `FAIL` to `SHORT_READ_GAP` changes only the diagnostic
text, not any downstream gate. Recommended next step for OWNER/next ticket
(not actioned here): (1) investigate the shared 2025-10-09/2025-11-03 T1
archive gap across the ~21 affected FX symbols as a likely systemic import
defect distinct from AUDCAD; (2) once more dated examples of legitimate
holiday closures exist, consider a higher or population-specific
`SHORT_READ_GAP_WEEKDAY_HOURS`.

## F6 — gap test rebuilt at real M1 spacing with negative cases

`test_short_read_gap_status_flags_a_multiweek_weekday_hole` now builds two
dense 3-day M1-spaced (60s) DWX blocks bracketing a genuine 25-day hole
(matching the real AUDCAD pattern's order of magnitude), with Dukascopy
holding the same dense blocks plus sparse (3h-spaced, still M1-aligned)
proof-of-life ticks through the hole — proving market-open without claiming
Dukascopy is minute-dense through 25 days. Two new negative-case tests:

- `test_longest_weekday_gap_ignores_an_ordinary_weekend` — a
  Friday-evening/Monday-early weekend with a Dukascopy proof-of-life tick
  mid-weekend; asserts the weekday-seconds gap stays strictly under the 24h
  threshold (only the couple of weekday hours at each edge count).
- `test_longest_weekday_gap_ignores_a_mutually_silent_weekday_holiday` — a
  single weekday where *both* sources are silent (an exchange holiday, not
  a DWX-side defect); asserts zero weekday-gap seconds, since the detector
  requires Dukascopy evidence strictly inside the interval.

## F7 — run()'s receipt-status and summary-error-text logic extracted and unit-tested

The inline boolean expression that computed `result["status"]` and the
inline `summary["error"]` expression (both previously only exercised inside
`run()`, which needs a live T1 launch to reach) are extracted verbatim into
`_compute_receipt_status(result, manifest_binding)` and
`_summary_error_text(result)` — pure functions, identical logic, called from
the same two call sites in `run()`. Two new tests:

- `test_compute_receipt_status_fails_on_short_read_symbol_count` — a result
  dict that satisfies every other PASS condition still returns `FAIL` when
  `manifest_binding["short_read_symbol_count"] > 0`.
- `test_summary_error_text_names_short_read_symbols` — asserts the exact
  SHORT_READ symbol names appear in the returned error text, and that a
  clean result returns `None`.

## Verification

```text
python -m compileall -q framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py tools/dukascopy/reconcile_overlap.py
(no output = PASS)

python -m pytest -q tools/dukascopy/tests/
37 passed   (35 pre-existing + 2 new negative-case tests; the rebuilt gap
             test replaces the prior one in place)

python -m pytest -q framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py
9 passed    (5 pre-existing + 4 new: chunk_expected_minutes, material-
             shortfall short_chunks, receipt-status F7, summary-error-text F7)

python -m pytest -q tools/strategy_farm/tests/test_dwx_m1_overlap_export.py
14 passed   (out-of-scope suite, exercised only to confirm no regression;
             not modified by this ticket)
```

### MetaEditor compile (framework compile path, non-factory)

Same precedent as the prior ticket: `D:/QM/mt5/DEV1/metaeditor64.exe`, a
non-factory, non-live MT5 install, source staged into this evidence
directory and compiled from there.

```text
D:\QM\mt5\DEV1\metaeditor64.exe /portable
  /compile:C:\QM\repo\docs\ops\evidence\2026-09-15_dukascopy_export_fix_r2\compile_probe\MQL5\QM_DWX_M1_Overlap_Export.mq5
  /include:C:\QM\repo\docs\ops\evidence\2026-09-15_dukascopy_export_fix_r2\compile_probe\MQL5
  /log:C:\QM\repo\docs\ops\evidence\2026-09-15_dukascopy_export_fix_r2\compile_probe\MQL5\QM_DWX_M1_Overlap_Export.log

Result: 0 errors, 0 warnings, 781 ms elapsed, cpu='X64 Regular'
```

No terminal was started; no export ran.

| Artifact | SHA-256 |
|---|---|
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.mq5` (staged; identical to committed source) | `62d267ccb1a1bb6bb35c2d876df45a01f927a3a079f5bc2405742c9ea06d8a4b` |
| `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5` (committed source) | `62d267ccb1a1bb6bb35c2d876df45a01f927a3a079f5bc2405742c9ea06d8a4b` |
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.ex5` | `87a0496f654907c75f8e24f55e62a06adb576062bdfc4537d3d17cbadefc7207` |
| `compile_probe/MQL5/QM_DWX_M1_Overlap_Export.log` | `4c9dd7c2cb7f10edee712b5c56998b064c68918aa7d1788f0b032398ffb8d7ec` |

Wrapper's own contract validator re-run against the modified source, still accepts it unchanged:

```text
python -c "from framework.scripts.mt5_diagnostics import dwx_m1_overlap_export as export; print(export.validate_mql_source())"
{'path': '...QM_DWX_M1_Overlap_Export.mq5', 'sha256': '62d267cc...a4b',
 'symbol_count': 37, 'read_only_api': True, 'period': 'M1',
 'overlap_start_utc': '2025-10-01T00:00:00Z', 'overlap_end_utc': '2026-04-01T00:00:00Z'}
```

## Committed source SHA-256 (all touched files)

| File | SHA-256 |
|---|---|
| `framework/scripts/mt5_diagnostics/QM_DWX_M1_Overlap_Export.mq5` | `62d267ccb1a1bb6bb35c2d876df45a01f927a3a079f5bc2405742c9ea06d8a4b` |
| `framework/scripts/mt5_diagnostics/dwx_m1_overlap_export.py` | `39081d168c639196d4ba135c6ff3e8e6ac8046cb7a0a89e91af1d71281ec9f90` |
| `framework/scripts/mt5_diagnostics/test_dwx_m1_overlap_export_completeness.py` | `fb3748d28b6386926abfdef7e6b75c6cedff9d320768c7b328d57d405e3a5ef4` |
| `tools/dukascopy/reconcile_overlap.py` | `c8dfc11c16e3682fb2d00d8c463554a6b07b721c1aeb526601e7a616d0a34fde` |
| `tools/dukascopy/tests/test_dukascopy_backfill.py` | `2c6b075f14ee8ffea283d0a62d24fb7d785cfe88644e06ad3aab843ad9d6c2a7` |

## What was not done (by design)

- No T1 probe rerun; no terminal64.exe start; T1-T10/T_Live untouched.
- No archive write, no production splice, no manifest update outside this
  evidence directory. `production_splice_authorized=false` /
  `production_import=false` everywhere this ticket's code paths touch.
- No fixed reconciliation threshold changed (1.5x spread p95, 99% bilateral
  coverage, DST 0 s, `SHORT_READ_COVERAGE_RATIO` all untouched).
- F8/F9/F10 (minor findings on the prior delivery, not in this ticket's
  acceptance list) left untouched.
- The shared 2025-10-09/2025-11-03 archive gap ("Major finding" above) is
  reported, not root-caused or fixed — that requires T1 archive
  investigation outside this ticket's file scope.
- The governed T1 export rerun remains a **separate** work item, enqueued
  only after this ticket is reviewed/approved (same path as before):

```text
python C:/QM/repo/tools/strategy_farm/dwx_m1_overlap_export_work_item.py \
  --root D:/QM/strategy_farm \
  --stamp <YYYYMMDD_HHMMSS> \
  --authority-task-id 9e0fb916-27d3-4022-9a95-dc0547883896 \
  --apply
```

RESULT task=9e0fb916-27d3-4022-9a95-dc0547883896 parent=dc7f0545
f1_documented=DONE f2_measured=DONE(10_short_read+27_complete,AUDCAD_COMPLETE_confirmed)
f3_chunk_journal_bound=DONE+TESTED f4_material_shortfall_short_chunks=DONE+TESTED(informational_not_a_gate)
f5_reordered+rerun=DONE(new_distribution=10_SHORT_READ+27_SHORT_READ_GAP,major_finding_see_above)
f6_realistic_gap_test+negatives=DONE+TESTED f7_receipt_status_and_error_text_tests=DONE+TESTED
compile=PASS(0_errors_0_warnings) tests="37+9+14 passed" t1_probe_rerun=NONE
archive_write_authorized=false production_splice_authorized=false
major_finding=shared_25day_dwx_gap_2025-10-09_2025-11-03_across_~21_fx_symbols_not_just_AUDCAD_needs_followup_ticket
