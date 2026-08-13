# Q14/Q15 categorical optimization contract — task 8afec595

Date: 2026-08-13  
Router task: `8afec595-cff2-4b41-8f0f-e5d435b7da56`  
Branch: `agents/board-advisor`  
Verdict: `IMPLEMENTED_AND_FOCUSED_TESTS_PASS_REVIEW_REQUIRED`

## Authority and scope

This artifact closes only routed items `B1_categorical_surface` and
`B2_categorical_selection` from the OWNER-authorized optimization-pipeline batch.
The binding plan is
`docs/research/PATTERN_PERMISSION_FILTER_PLAN_V2_2026-08-13.md`.

No Q14/Q15 production row was created. No command used `--apply`. The live farm DB
was not mutated by the implementation or tests. No terminal was launched, no
factory state was changed, and T_Live, FTMO, AutoTrading, and active backtests were
untouched.

## Implementation

Implementation commit: `a196344dd` (`feat(opt): add categorical predicate contracts`).

Upstream contract commits retained as prerequisites:

- DSR selection multiplicity: `c99db8847`
- sharpe-std calibration decision: `fdb5997f8`
- exact-family PBO enforcement: `a0a6668bc`
- pattern-permission P1 core: `28a7f676f`
- straddle A1/A2 integration: `f62763300`

### B1 — Q14 categorical surface

- Added `PREDICATE_ABLATION` to Q14's supported lever set and the opt-card schema.
- Added a separately gated `surface_type=CATEGORICAL` branch. It requires
  `parameters=[]`, a positive integer `minimum_dev_fire_count`, and 2–64 unique
  named predicate/direction declarations.
- Normalized directions to `BUY`/`SELL` and emitted exact planned rows shaped
  `{trial_id, predicate_id, direction}`.
- The categorical branch does not request numeric bounds and does not execute a
  `float()` cast.
- The pre-existing numeric branch remains separate, still requires explicit
  numeric bounds/candidates, and still rejects named candidates.
- Existing global/per-parent cap arithmetic and the 64-trial surface cap are
  unchanged.

### B2 — Q15 categorical selection

- Gated the categorical selector on both lever `PREDICATE_ABLATION` and
  `surface_type=CATEGORICAL`; mismatched lever/type pairs fail closed.
- Kept the numeric card contract and ordered 5% adjacent-plateau selector in a
  separate helper. Numeric cards still require exactly one tunable parameter and
  still cast all candidate values through `float()`.
- Added an incumbent-bound categorical DEV evidence contract with exactly three
  disjoint, contiguous, near-equal time-thirds covering the complete DEV window.
- Enforced the replacement rule in fail-closed order:
  1. the chosen trial must first satisfy the declared DEV fire-count floor;
  2. its DEV objective improvement over the incumbent must meet the card's
     declared absolute `minimum_improvement`;
  3. it must beat the incumbent in at least two of the three DEV time-thirds.
- Ineligible low-fire trials are excluded from the categorical eligible set and
  from its reported best eligible metric.
- Extended `opt_dev_sweep.v1.schema.json` to distinguish numeric and categorical
  trial/evidence shapes. Structural schema assertions and JSON parsing are covered
  without adding a runtime dependency on `jsonschema`.

## Focused verification

Canonical checkout:

```text
python -m pytest tools/strategy_farm/tests/test_q14_opt_admission.py tools/strategy_farm/tests/test_q15_freeze_check.py tools/strategy_farm/tests/test_optimization_track_manifest_v2.py tools/strategy_farm/tests/test_q16_head_to_head.py -q
........................................                                 [100%]
40 passed in 4.60s
```

Interactive Administrator filesystem context, with the required AppData basetemp:

```text
python -m pytest tools/strategy_farm/tests/test_q14_opt_admission.py tools/strategy_farm/tests/test_q15_freeze_check.py tools/strategy_farm/tests/test_optimization_track_manifest_v2.py tools/strategy_farm/tests/test_q16_head_to_head.py -q --basetemp C:/Users/Administrator/AppData/Local/Temp/qm_task8_opt_contract_20260813_1503
........................................                                 [100%]
40 passed in 4.07s
```

Additional focused checks:

```text
python -m py_compile framework/scripts/q14_opt_admission.py framework/scripts/q15_freeze_check.py
python -m json.tool tools/strategy_farm/config/opt_card.v1.schema.json
python -m json.tool tools/strategy_farm/config/opt_dev_sweep.v1.schema.json
git diff --check -- <six scoped implementation/test/schema paths>
```

All completed with exit code 0. The focused tests explicitly prove deterministic
categorical Q14 dry runs, exact named trial rows, unchanged cap tests, numeric
non-numeric rejection, low-fire rejection before objective comparison,
minimum-improvement rejection, knife-edge time-third rejection, a passing
three-condition categorical case, and that the ordered numeric helper is not entered
for categorical cards.

## Review boundary

This is code-contract evidence, not pipeline evidence and not a strategy-performance
verdict. No census was enqueued. The implementation and this artifact remain for
Claude+OWNER close-review; they do not authorize PIPELINE or live use.
