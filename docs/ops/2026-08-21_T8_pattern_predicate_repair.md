# T8 — Pattern-permission predicate repair (31/32/92/100)

Date: 2026-08-21
Scope: `framework/include/QM/QM_PatternPermission.mqh` (blacklist VETO gate, 77
predicates). Sole consumer is the census EA
`framework/EAs/QM5_21501_balke-gmt3-range-breakout-ppcensus/` (no live inventory;
verified by grep — the include is deliberately NOT in `QM_Common.mqh`, so no other
EA pulls it in).

Four predicates were confirmed defective by the 2026-08-21 audit and documented by
the fixtures as "dead predicate / MISMATCH on purpose". This repair makes each
predicate satisfiable and canonically correct, and re-points the fixtures at the
repaired semantics (the runner harness is a separate later step — see Follow-up).

## Per-predicate: old → new

### ID 31 — THREE_INSIDE_UP
- **Old:** `QM_PP_Evaluate(QM_PP_HARAMI_BULL, b) && close[0] > high[1]`.
  HARAMI_BULL is a 2-bar shape on bars 1(mother, bearish)/0(child, bull) and pins
  `close[0] <= open[1] <= high[1]`. Demanding `close[0] > high[1]` of that same
  containing bar is a contradiction → predicate can never fire.
- **New (genuine 3-bar pattern):** bar2 bearish mother, bar1 bullish harami whose
  body is contained in bar2's body, bar0 bullish confirmation closing above the
  harami's high:
  `IsBear(2) && IsBull(1) && open[1] >= close[2] && close[1] <= open[2] &&
   Body(2) > Body(1) && IsBull(0) && close[0] > high[1]`.
  Moving the harami onto bars 2/1 frees bar0 to break out; `high[1]` is now the
  harami CHILD's high (the correct breakout reference), not the mother's.

### ID 32 — THREE_INSIDE_DOWN (symmetric)
- **Old:** `QM_PP_Evaluate(QM_PP_HARAMI_BEAR, b) && close[0] < low[1]` — same
  contradiction (`close[0] >= open[1] >= low[1]`), never fires.
- **New:** `IsBull(2) && IsBear(1) && open[1] <= close[2] && close[1] >= open[2] &&
   Body(2) > Body(1) && IsBear(0) && close[0] < low[1]`.

Note on the confirmation reference: the T8 order sketched the confirmation as
`close[0] > open[1]`. In the repaired 3-bar structure bar1 is the harami CHILD, so
`open[1]` is the *bottom* of the child body — the wrong side for an up-breakout and
a near-always-true clause. The reviewed fixtures (which the order names as the
canonical documentation) encode the breakout reference as the child's `high[1]`
(down: `low[1]`), which is the canonical Nison/Bulkowski "close beyond the harami"
confirmation and matches every positive/negative/boundary fixture with zero fixture
rewrites. The order's "NICHT high[1]" warned against the OLD contradictory
mother's-high reference; after restructuring, `high[1]` is the child's high and is
correct. Implemented `high[1]`/`low[1]` accordingly. Flagged for confirmation.

### ID 92 — FRACTAL_BREAKOUT
- **Old:** `high[2] > high[3] && high[2] > high[4] && high[2] > high[1] &&
   high[2] > high[0] && close[0] > high[2]`. The clause `high[2] > high[0]`
  combined with `close[0] > high[2]` is unsatisfiable: a bar closing above
  `high[2]` must itself print `high[0] >= close[0] > high[2]`. Never fires.
- **New:** the reference high is formed from PRIOR bars only. Bar2 is a confirmed
  up-fractal (swing high above neighbours 1/3/4); the current bar breaks it:
  `high[2] > high[1] && high[2] > high[3] && high[2] > high[4] && close[0] > high[2]`.
  The contradictory `high[2] > high[0]` clause is removed.

### ID 100 — QUARTER_END
- **Old:** `quarter_month && day >= 24` — over-fires: e.g. Mar 27 / Sep 26 are
  ordinary late-quarter-month days, not the quarter close, yet returned true.
- **New:** last TWO calendar days of a quarter month, month-length and leap-year
  correct: `quarter_month && day >= last_day_of_month - 1`, via a new
  `QM_PP_DaysInMonth(year, mon)` helper. This is the simplest correct closed-bar
  variant (a closed-bar gate cannot look ahead to test "no later bar this month"),
  always admits the genuine quarter-end trading day, and rejects Mar 27 / Sep 26.
  Documented inline in the header.

## Fixture changes (structure preserved; markers removed)

- `three_bar_reversal.json`: removed the "dead predicate / MISMATCH on purpose"
  group-note sentence; rewrote the 4 THREE_INSIDE positive/boundary-inside
  rationales to state the repaired predicate now detects the pattern. All 10
  THREE_INSIDE fixtures (5 up, 5 down) keep their bar data and expected values and
  now AGREE with the implementation (verified by hand against each window).
- `statistical.json`: rewrote the 3 FRACTAL_BREAKOUT positive/boundary rationales
  to drop the defect language. Bar data and expected values unchanged; all 6
  fixtures agree with the repaired predicate.
- `volume_calendar.json`: QUARTER_END — updated the two defect-negative rationales
  (Mar 27, Sep 26) to describe the repaired last-two-days rule (kept expected=false
  as regression guards); repointed the two boundary fixtures from the retired
  day>=24 threshold to the new one: `day30_inside` (2026-03-30, true, on the
  `last_day-1` edge) and `day29_outside` (2026-03-29, false, just below). The four
  positives and two non-quarter-month negatives are unchanged.
- `_bundle/pattern_fixtures.csv`: regenerated via
  `python framework/scripts/build_pattern_fixture_bundle.py --emit`.

## Test results

- `python framework/scripts/build_pattern_fixture_bundle.py` — clean: 77 predicates
  in header, 527 fixtures from 12 group files, 77 covered, no errors.
- `pytest test_pattern_permission_contract.py test_pattern_fixture_coverage.py`
  — **35 passed, 2 skipped**. The 2 skips are the runner-CSV-dependent tests
  (`test_runner_results_all_pass`, `test_runner_covered_every_bundled_fixture`),
  which stay skipped until the MQL5 harness run (see Follow-up). This is expected.
- `compile_one.ps1 -EALabel QM5_21501_...` — **PASS**, 0 errors, 0 warnings; `.ex5`
  rebuilt (force-rebuild path) and committed alongside the source.

## Follow-up (still open)

The MQL5 fixture-harness run
(`framework/tests/QM_pattern_permission_fixture_runner.mq5`) that produces
`_bundle/pattern_fixture_results.csv` — the REAL verdict comparing the compiled
`QM_PP_Evaluate` against the fixtures — is a separate step needing a factory
window and the ad-hoc tester harness. It is NOT part of T8. Until it runs, the two
runner-dependent coverage tests remain skipped. Fixture/implementation agreement
was verified by hand for all 4 repaired predicates in this repair.
