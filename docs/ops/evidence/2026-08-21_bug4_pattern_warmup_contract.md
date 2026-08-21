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
  fallback); the fallback is never silent.
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

Eight T1-T10 backtests were active under the hard CPU ceiling. The harness was
not run ad hoc, no terminal was started, and no active backtest was interrupted.
Task acceptance remains open until the governed result contains the real
first-tradable marker and proves both evidence consumers can ingest it. Only
then may the task move to REVIEW and the first `PATTERN_FILTER_COMBO` trial be
scheduled.
