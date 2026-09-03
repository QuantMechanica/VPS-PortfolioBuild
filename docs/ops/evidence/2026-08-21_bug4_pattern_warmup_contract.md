# Bug #4 — pattern-filter warm-up contract and pending runtime proof

- Router task: `a764edd0-7f5b-4786-85be-e646ef1b82b5`
- Authority: Claude orchestrator, 2026-08-21
- Implementation commit: `f09c2a1c3add2aa6f4e9ec7374697edf4db853aa`
- Current verdict: **IMPLEMENTATION_VERIFIED; GOVERNED_RUNTIME_EVIDENCE_PENDING**
- Optimization consequence: do not schedule the first
  `PATTERN_FILTER_COMBO` trial yet.

The fail-closed history denial is correct and remains unchanged. Bug #4 is the
downstream distortion created when frequency/activity consumers silently score
the whole requested interval even though the pattern gate could not trade its
leading bars. The repair makes the first tradable bar explicit and makes older
marker-less evidence visibly fall back to its historical substitute.

## B4-1 — measured specification

Reproduction command:

```powershell
python framework/scripts/audit_pattern_warmup.py --output docs/ops/evidence/2026-08-21_bug4_pattern_warmup_measurement.json
```

The source-bound audit enumerates all 77 implemented predicates, reads their
actual `QM_PP_RequiredBars` depths, and walks the exact availability boundary
from zero through the required count. The committed artifact is
`docs/ops/evidence/2026-08-21_bug4_pattern_warmup_measurement.json` with schema
`qm.pattern-warmup-measurement/v1`.

Measured predicate counts by required closed-bar depth:

| Required bars | Predicates | Leading bars denied | First tradable current-bar index |
|---:|---:|---:|---:|
| 1 | 2 | 1 | 1 |
| 3 | 47 | 3 | 3 |
| 4 | 3 | 4 | 4 |
| 6 | 6 | 6 | 6 |
| 7 | 1 | 7 | 7 |
| 8 | 1 | 8 | 8 |
| 11 | 7 | 11 | 11 |
| 12 | 2 | 12 | 12 |
| 21 | 3 | 21 | 21 |
| 22 | 3 | 22 | 22 |
| 101 | 2 | 101 | 101 |

The first denied bar is `reference_bar_unavailable`; for depth `N`, the next
`N-1` bars are `insufficient_or_invalid_history`. The worst case is the two
volume-percentile predicates at 101 bars. Nominal time to the first tradable bar
is therefore 505 minutes on M5, 1,515 minutes on M15, 101 hours on H1, 404 hours
on H4, and 2,424 hours on D1. These are bar-duration measurements only; weekends
and market closures are deliberately not converted into wall-clock estimates.

## B4-2 — cache scope verdict

**NO DEFECT: the denial cache is reference-bar scoped.** The exact key at
`QM_PatternPermission.mqh:978-979` is:

```text
symbol + "|" + reference_tf + "|" + ref_bar + "|" + QM_PP_ProfileKey(profile)
```

The denial stored at lines 997-1002 can be reused only for that symbol,
timeframe, reference-bar timestamp, and profile. A new reference bar changes
`ref_bar`, so the old denial cannot outlive its bar. No cache fix was made.

## B4-3 — first-tradable marker

After the first successful history load for a symbol/timeframe/profile scope,
`QM_PP_RecordFirstTradable` emits:

- structured logger event `PATTERN_FIRST_TRADABLE_BAR`, schema
  `qm.pattern-first-tradable-bar/v1`; and
- tester-log marker `QM_PATTERN_FIRST_TRADABLE_BAR` with symbol, reference
  timeframe, tradable/reference timestamps, required bars, and profile key.

The bounded scope registry emits the marker once per active scope and never
changes the gate decision. Older runs cannot masquerade as measured runs because
the evidence parser reports marker status `absent` explicitly.

## B4-4 — both consumers

- Q02 frequency: `run_smoke.ps1` parses the logger/tester marker, starts the
  annualized window at the measured tradable date, and records
  `coverage_start_source`, `marker_status`, `coverage_start`, `coverage_end`,
  year count, and calculated minimum trades. With no valid marker it uses
  `test_window_start_fallback_marker_absent` (or the visible invalid-marker
  fallback); the fallback is never silent. **Amended 2026-09-03, see B4-5:**
  the emitted block is schema `qm.q02-frequency-coverage/v2`, markers are
  attributed per RUN rather than per (EA, symbol), and a third fallback
  value `test_window_start_fallback_marker_not_attributable` exists.
- Activity criterion: `audit_activity_criterion.py` reads the generation-bound
  Q02 summary marker. It uses that date for entry/close coverage when valid;
  otherwise it retains the historical earliest-trade substitute and labels the
  output `earliest_trade_fallback_marker_absent` or
  `earliest_trade_fallback_invalid_marker_after_trade`, including marker status.

No threshold, verdict, or pipeline criterion changed.

## Focused verification

- `python -m pytest -q framework/scripts/tests/test_pattern_permission_contract.py framework/scripts/tests/test_pattern_warmup_audit.py tools/strategy_farm/tests/test_activity_criterion_prorata.py`:
  **53 passed**.
- `python -m pytest -q tools/strategy_farm/tests/test_pattern_fixture_harness_dispatch.py`:
  **2 passed**.
- `framework/scripts/tests/Test-PatternWarmupEvidence.ps1`:
  **PASS**, including present, absent, invalid, and conflicting marker cases.
- Fixture runner compile: **PASS, 0 errors, 0 warnings**. EX5 SHA-256:
  `482fa5f497dd3dcd25db11044b0b266f64d1cef94d656a6ecdd1e1e8997ff181`.
- The committed 77-predicate measurement reproduces depth range 1 through 101
  and the reference-bar cache-key verdict above.

## Governed runtime proof still required

Work item `83b89730-bb86-4c18-955a-efefe3039cc5` is the dedicated
`HARNESS_PP_FIXTURE` run for `QM_PP_FIXTURE_HARNESS`, EURUSD.DWX D1,
2024-01-02 through 2024-01-10. At the end of this orchestration pass it remains:

- status `pending`;
- attempt count `0`;
- unclaimed; and
- without evidence path or verdict.

The final read-only recheck at `2026-08-21T10:37:09Z` still found the harness
pending, attempt count zero, unclaimed, and without an evidence path or verdict.
Farm health simultaneously reported 10 active work items and all 10 T1-T10
worker daemons alive, with 2,231 pending rows. The harness was not run ad hoc,
no terminal was started, and no active backtest was interrupted.

This single-pass orchestration cycle hands the implementation to REVIEW with an
explicit `GOVERNED_RUNTIME_EVIDENCE_PENDING` residual. Task acceptance remains
open until the governed result contains the real first-tradable marker and proves
both evidence consumers can ingest it. The first `PATTERN_FILTER_COMBO` trial
remains prohibited until that proof is reviewed and accepted.

## B4-5 - 2026-09-03 amendment: per-run marker attribution (schema v2)

- Authority: Claude orchestrator, 2026-09-03 (GRUEN: infra repair that does not
  touch verdict logic; no gate threshold and no gate criterion changed).
- Defect class: the tester day-log is a SHARED terminal artifact. The v1 parser
  text-scanned it and adopted any `QM_PATTERN_FIRST_TRADABLE_BAR` line it found.
  Two fail-open leaks followed, both measured on production artifacts:
  - **cross-EA** - work item `95e706ea-531c-504b-ae46-4e16f7d79134`
    (QM5_41321 / NDX.DWX, run_tag `20260903_012953`) recorded
    `first_tradable_bar.symbol=XAGUSD.DWX`, emitted by QM5_41195. Coverage start
    moved 2021.01.01 -> 2022.01.12, year count 2 -> 1, floor 10 -> 5.
  - **cross-RUN** - the same day-log holds four QM5_41196 / XAUUSD.DWX markers
    from four DL089 census cells (1-year windows, four distinct `profile_key`s).
    An (EA, symbol)-only rule adopts the latest of them for the canonical
    2018.07.02-2022.12.31 Q02 run: floor 25 -> 5.

### Attribution rule (fail-closed)

A marker may move `coverage_start` only when all three hold:

1. **Run window.** Its day-log clock lies inside this run's own tester window.
   The window is anchored on the tester's own run-start line
   `<symbol>,<tf>: testing of Experts\<expert>.ex5 from <from> 00:00 to <to> 00:00 started with inputs:`,
   required to match this run's expert leaf, this run's symbol AND the exact
   requested window (`from_date`/`to_date`) - the same triple
   `Test-TesterLogHasNoHistoryForRun` already uses to scope history failures to
   the current run. The LAST such line is this run (run_smoke copies the day-log
   immediately after the run finishes); the window closes at the next run
   boundary (`expert file added:` or another run-start line) or at end of log.
2. **Source identity.** The day-log source column names this expert, or - for
   the tester-core layout that carries no EA identity - rule 1 plus rule 3 carry
   the scoping (`core_source_window`).
3. **Symbol scope.** The marker symbol is the run symbol, or the emitting chart
   is the run's own chart symbol (multi-symbol basket member).

The structured-logger sample is exempt from rule 1: `run_smoke.ps1` captures it
as a per-run delta of this EA's logger files (`Save-QmLoggerDelta`
`-BeforeState` / `-EAIdValue`), so the artifact is already run-scoped
(`run_scope.logger_sample_scope = per_run_delta_capture`).

### Two production day-log layouts

Measured 2026-09-03 over all 1,058 retained production day-logs (819 of them
carrying markers, 2,921 marker lines in total); no third layout exists:

| layout | source column | share | attribution |
| --- | --- | --- | --- |
| 1 | `QM5_41321_grimes-trendday-v2-opt (NDX.DWX,M15)` | 2,782 (95.2%) | run window + expert + symbol |
| 2 | `Core 01`, e.g. `IE<TAB>0<TAB>03:27:52.986<TAB>Core 01<TAB>...` | 139 (4.8%) | run window + symbol, reason `core_source_window` |

Layout 2 carries no EA identity at all. Rejecting it outright would silently
disable the Bug #4 marker for any run whose only marker source is such a journal
and whose `logger_sample.jsonl` is missing, so it is attributed on the run window
plus the run symbol instead - that window belongs to exactly one dispatched run
on that terminal.

### Emitted values (schema `qm.q02-frequency-coverage/v2`)

`coverage_start_source`:

- `pattern_first_tradable_bar`
- `test_window_start_fallback_marker_absent`
- `test_window_start_fallback_marker_invalid_or_outside_window`
- `test_window_start_fallback_marker_not_attributable` *(new in v2)*

`marker_status`: `present_consistent`, `present_conflict_conservative_earliest`,
`absent`, `invalid_or_outside_window`, `present_not_attributable` *(new in v2)*.

Per-marker `attribution_reason` - attributed: `own_ea_run_symbol`,
`own_ea_member_symbol`, `core_source_window` *(new in v2)*; rejected:
`no_expected_run_identity`, `run_window_unresolved` *(new)*,
`outside_run_window` *(new)*, `marker_line_without_timestamp` *(new)*,
`source_line_without_ea_identity`, `foreign_ea`, `foreign_symbol`.

New v2 fields: `run_window_enforced`, `attributed_profile_key_count`,
`attributed_profile_keys`, and `run_scope` with per-file `tester_log_windows[]`
(`window_source`, `window_start`, `window_end`, `exact_run_start_count`,
`own_ea_symbol_run_start_count`, `run_start_count`, `marker_count`,
`attributed_marker_count`); each marker additionally carries `source_column`,
`source_column_kind`, `source_line_time`, `run_window_state` and
`run_window_source`. Together they let a reviewer - or
`tools/strategy_farm/portfolio/audit_activity_criterion.py` - tell a same-run
marker from a cross-run one without re-reading the day-log.

`run_scope.tester_log_windows[].window_source`:

- `tester_log_run_start_exact` - anchored on this run's own run-start line.
- `rollover_continuation_no_run_start` - the day-log contains NO run-start line
  at all, i.e. the run started before 00:00 and `run_smoke.ps1` copied the
  current day file; such a file carries exactly one run's output. Measured
  2026-09-03: 4 of 1,059 retained production day-logs (0.4%).
- `unresolved_no_matching_run_start`, `unresolved_no_expected_run_identity`,
  `unresolved_log_missing`, `unresolved_window_not_supplied` - fail-closed: every
  marker in the file is rejected and the full test window is scored.

Measured resolution rate over all 1,059 retained production day-logs that still
have a summary: 1,053 anchored on their own run-start line, 4 rollover
continuations (all already `marker_status=absent`), 2 unresolved - 99.8%
resolved. Both unresolved files are the INVALID first leg of a two-leg run
whose OK leg resolves normally, e.g. work item
`71d1ad66-3f15-463c-ac55-76a0b09a86cd` (QM5_11910 / NZDUSD.DWX,
2018.07.02-2022.12.31), whose v1 evidence had adopted a QM5_41301 / QM5_41302
XAUUSD.DWX census marker (coverage start 2019.01.02, floor 20). Under the new
rule run_02's own window resolves, all 22 markers are rejected
(19 `run_window_unresolved` from the INVALID leg, 3 `outside_run_window`) and
the floor returns to 25 - the run's 33 trades still PASS.

### Direction of the change

Every rejection falls back to the requested test-window start: MORE coverage,
MORE scored years, a STRICTER floor. The repair can therefore only raise a
frequency floor, never lower one. No threshold and no gate criterion moved.

### Retroactive scope

Inventory run 2026-09-03: 17,162 run summaries scanned, 9,657 carrying a
frequency-floor block since 2026-08-01, **3,312 affected rows** - 463 with a
provably foreign marker symbol, 157 conclusively re-parsed (every one of them
with a moved coverage start), 2,818 no longer checkable because D: retention
purged the quoted day-log. **4 rows would flip the Q02 verdict**
(QM5_36005 / AUDNZD.DWX and QM5_41264 / QM5_41267 / QM5_41271 on XTIUSD.DWX:
floor 10 instead of 25 with 19-24 trades); all four already carry a FAIL
work-item verdict, so no standing PASS rests on the leak. (The factory keeps
writing summaries, so a re-run of the inventory drifts by a handful of rows;
the committed CSV is the 2026-09-03 06:5xZ snapshot.)

The change corrects future runs only. Q02 evidence written under v1 is not
rewritten and no verdict is regraded - regrades are an OWNER decision (ROT:
"delete/overwrite verdicts or trade streams"). The read-only inventory
`docs/ops/evidence/2026-09-03_q02_frequency_floor_leak_inventory.py` enumerates
the affected rows and writes
`docs/ops/evidence/2026-09-03_q02_frequency_floor_leak_inventory.csv`
(`floor_used` vs `floor_fail_closed`, plus the live work-item verdict) as the
OWNER decision input. It performs no database writes.

### Verification

- `framework/scripts/tests/Test-PatternWarmupEvidence.ps1`: **PASS**.
- `python -m pytest -q framework/scripts/tests/test_q02_frequency_floor_attribution.py`:
  **9 passed**.
- Production replay, cross-RUN case (the 2026-09-03 refutation command) against
  `D:\QM\reports\work_items\95e706ea-531c-504b-ae46-4e16f7d79134\QM5_41321\20260903_012953\raw\run_01\20260903.log`
  with `-ExpectedExpert 'QM\QM5_41196_qs-kama-trend-xau-opt' -ExpectedEaId 41196 -RunSymbol 'XAUUSD.DWX' -FallbackStartDate '2018.07.02' -EndDate '2022.12.31'`
  -> `coverage_start=2018.07.02`, `year_count=5`, `min_trades_required=25`,
  all 5 markers rejected `run_window_unresolved`
  (v1 / (EA, symbol)-only: 2022.01.03, 1 year, floor 5).
- Production replay, the original defect run (QM5_41321 / NDX.DWX,
  2021.01.01-2022.12.31, same day-log) -> window `03:30:39.592..end_of_log`,
  all 5 foreign markers rejected `outside_run_window`, floor back to 10 (was 5).
- Production replay, tester-core layout (QM5_41097 / USDJPY.DWX,
  2022.01.01-2022.12.31,
  `D:\QM\reports\work_items\6d08514a-21e4-560a-b2e6-54f69a97679d\QM5_41097\20260902_173801\raw\run_01\20260902.log`)
  -> `coverage_start=2022.01.03` attributed via `core_source_window`, 60 of 61
  markers rejected `outside_run_window`.
