# OPT_CENSUS selection + advance driver — F2 (review R2)

**Date:** 2026-08-22 (authored; filename pinned by the F2 brief to 2026-08-21)
**Author:** Claude (board-advisor lane)
**Scope:** Complete the DL-089 census tooling per review R2 — ledger sealing, the
Q02 precondition, numeric machinery, and the walk-forward selection + advance
state-machine driver. Optimization branch only (measurement pool `OPT_CENSUS`); the
core funnel Q00–Q13 and all gate verdict logic are untouched (ROT).
**Authorities:** `docs/research/PATTERN_FILTER_WF_OPT_PLAN_V3_2026-08-21.md` §2
(sealed rule), `decisions/DL-089_pattern_filter_wf_census_v3.md` (incl. Nachtrag numeric
stage + Nachtrag 2 order),
`decisions/DL-088_optimization_track_v2_levers_and_overfit_contract.md`.

## Files

| File | Change |
|---|---|
| `tools/strategy_farm/opt_census.py` | **additive** — sealed header (rule text+sha, floors, quorum, WF windows, param-grid sha), Q02 precondition, `advance`/`report` subcommands wired to the driver. Matrix/enqueue mechanics unchanged. |
| `tools/strategy_farm/opt_census_select.py` | **new** — pure WF-selection library + the idempotent pilot state-machine driver + numeric machinery. |
| `tools/strategy_farm/tests/test_opt_census.py` | extended — sealed header, Q02 precondition (fixture `_db` now seeds a done/PASS Q02). |
| `tools/strategy_farm/tests/test_opt_census_select.py` | **new** — 15 hand-computable fixtures (each expected value derived by arithmetic in a comment). |

## The sealed contract (written into every ledger header)

`build_plan`/`enqueue` freeze the evaluation **before any data is seen**:

- `sealed_rule_text` — the verbatim DL-089 §2 walk-forward protocol paragraph. It is
  **not retyped** (unicode transcription risk); `extract_sealed_rule_text()` pulls it
  live from the plan between two ASCII anchors and pins it by
  `sealed_rule_sha256 = 4cc2bbd108bf500f33ef5eee30536c9a4afe58dc2684116a972c0bfb65f3d383`.
  Any edit to the plan's §2 changes the extracted sha and makes the seal **fail closed**
  — the ROT tamper guard the Standing Authorization requires.
- `activity_floor = 10`, `relative_improve_min = 0.05`, `selection_year_quorum = "2/3"`.
- `wf_windows` — the 4 anchored steps (2019–21→22, …, 2019–24→25).
- `param_grid_sha256` — sha256 of the EA's `opt_param_grid.json` (path from `--param-grid`),
  so the numeric stage can prove the grid never changed between planning and optimisation.

## Preconditions (fail-closed, both required at `enqueue`)

1. **Fixture harness green** (existing) — work item `83b89730…` done/PASS.
2. **Q02 done/PASS for the census EA** (new, R2 #2) — spending 1,085 backtests is only
   justified once the `_opt` baseline is economically alive. Accepts phase `Q02` or the
   legacy `P2` key. Override with `--q02-ea-id` if the gate should point at a sibling.

## Numeric machinery (R2 #3)

`load_param_grid()` reads `opt_param_grid.json` via its **recorded sha**, validating the
`qm.opt-param-grid.v1` schema: each parameter carries ≤5 distinct `candidate_values`
**including** the `parent_value` as the mandatory control cell (DL-088 AI_PARAM).
`register_numeric_stage()` increments
`declared_trial_count_effective = 154 + Σ (candidate_values − parent)` and persists it to
the ledger **before any numeric cell is enqueued** (years are repeated measurement, not
trials — OWNER entscheid #7). The Q16 deflation later runs over the effective total.

**Expected grid schema** (for F1 at
`framework/EAs/QM5_41097_.../opt_param_grid.json`):

```json
{ "schema": "qm.opt-param-grid.v1", "ea_id": "QM5_41097",
  "parameters": [
    {"name": "strategy_max_range_atr_mult", "parent_value": 2.5, "candidate_values": [1.5, 2.0, 2.5, 3.0, 3.5]},
    {"name": "strategy_trail_trigger_r",    "parent_value": 1.0, "candidate_values": [0.5, 0.75, 1.0, 1.25, 1.5]},
    {"name": "strategy_range_end_hour",     "parent_value": 6,   "candidate_values": [5, 6, 7, 8]} ] }
```

Names are the parent EA's already-wired levers (the invented `opt_*` placeholders were
removed by review R1 as unwired). `parent_value` MUST appear **among** `candidate_values`
as DL-088's mandatory control cell; the trial increment counts only the non-parent
candidates (here (5−1)+(5−1)+(4−1) = 11).

## The advance state machine (R2 #4; reordered per DL-089 Nachtrag 2, 2026-08-22)

`opt_census.py advance` runs one deterministic, idempotent step. Every derived run lives
in the `OPT_CENSUS` pool with a deterministic uuid5 cell key (`INSERT OR IGNORE`), so
re-running never duplicates. A transition is appended to the ledger **only** when the
state actually changes, each with an `inputs_digest`.

**Sealed order (DL-089 Nachtrag 2, "S5 muss vor S4 passieren"):** the numeric stage now
runs BEFORE the full-window test, and there is no separate filter-only full-window test
any more. The single final full-window run of the FINAL configuration (frozen filters +
chosen numerics) IS the confirmation. The old `FULLWINDOW_MEASURING` and
`CONFIRM_MEASURING` states were merged into `FINAL_FULLWINDOW_MEASURING`.

```
ENQUEUED                  all 1,085 census cells MEASURED → compute 4 WF-step selections,
                          enqueue 4 combo test-year runs             → WF_COMBO_MEASURING
WF_COMBO_MEASURING        4 combo runs MEASURED → stability_check
                             stable   → freeze step-4 selection, register numeric stage
                                        (increment trials BEFORE enqueue), enqueue numeric
                                        cells (7 per-year frozen-combo baselines + Σvals×7,
                                        all WITH the frozen filter inputs)
                                                                     → NUMERIC_MEASURING
                             unstable → WF_UNSTABLE (STOP; OWNER review)
                             (no --param-grid → hold in WF_COMBO; verdict recomputes)
NUMERIC_MEASURING         numeric cells MEASURED → per-parameter plateau-median selection,
                          enqueue ONE final full-window pair: role=final (frozen filters +
                          chosen numerics) + role=baseline (parameter-parent, no filter),
                          both 2019..max                             → FINAL_FULLWINDOW_MEASURING
FINAL_FULLWINDOW_MEASURING both runs MEASURED (this IS the confirmation)
                                                                     → READY_FOR_Q15  (STOP)
```

`READY_FOR_Q15` **stops the machine** — Q15 is never automatic (DL-088 §3). Infra-failed
cells are re-enqueued append-only, bounded to **2 attempts**, the old row kept as evidence.
The numeric per-year cells carry the frozen filter combo (the same-year `role=baseline`
uses the frozen filters at parent numerics); the final full-window `role=baseline` is
parameter-parent + no filter for the honest baseline comparison.

### Sealed selection rule as implemented (exact)

- return_to_maxdd per arm per year vs the **same-year baseline**;
- **activity floor ≥ 10 entry days in every selection year, checked FIRST** — one breach
  makes the arm inadmissible before any return is scored;
- qualification = **≥ +5% relative in ≥ 2/3 of the selection years** (quorum = `ceil(2n/3)`);
- rank by consistency, then mean relative improvement, then predicate id (asc, deterministic);
- **≤ 3 per direction**; the six-zero baseline is always the control;
- stability = combo not worse on return_to_maxdd in **≥ 3/4** test years AND the final
  (step-4) selection is identical-or-**subset** of **≥ 2/3** earlier steps;
- the numeric stage picks the **plateau median** value of the qualifying set, never the best.

### ⚠ Flagged discrepancy — subset vs superset (needs an OWNER word)

The F2 brief paraphrases the stability sub-criterion as *"final selection
identical-or-**superset**"*. The **sealed plan §2** (the ROT authority whose sha this
driver hashes) says *"identisch oder **Teilmenge**"* = identical-or-**subset**. Since the
sealed text governs and I hash it verbatim, `stability_check` implements **subset**: every
filter in the final selection must also have been chosen by the earlier, smaller-window
steps (the more robust, Goodhart-resistant reading). If the brief's "superset" was the
OWNER's intent, that is a change to a sealed ROT rule and needs a new OWNER decision — one
line flip in `stability_check` (`final <= earlier`). Parked in the decision queue, not
silently resolved.

## Operating commands (monitoring loop)

```powershell
cd C:/QM/repo
$L = "D:/QM/strategy_farm/state/opt_census_QM5_41097_USDJPY_ledger.json"
$G = "framework/EAs/QM5_41097_balke-gmt3-range-breakout-opt/opt_param_grid.json"

# 0. Plan + seal (dry) — verifies the sealed header incl. the grid sha.
python -m tools.strategy_farm.opt_census plan --ea-id QM5_41097 `
  --ea-label QM5_41097_balke-gmt3-range-breakout-opt --symbol USDJPY.DWX --timeframe H1 `
  --base-setfile <base.set> --output-dir D:/QM/strategy_farm/opt_census/QM5_41097 --param-grid $G

# 1. Enqueue the 1,085-cell census (needs green harness + done/PASS Q02).
python -m tools.strategy_farm.opt_census enqueue --ea-id QM5_41097 `
  --ea-label QM5_41097_balke-gmt3-range-breakout-opt --symbol USDJPY.DWX --timeframe H1 `
  --base-setfile <base.set> --output-dir D:/QM/strategy_farm/opt_census/QM5_41097 `
  --param-grid $G --ledger $L

# 2. Monitoring loop — read state, then advance one step when a stage is complete.
python -m tools.strategy_farm.opt_census report  --ledger $L
python -m tools.strategy_farm.opt_census advance --ledger $L --param-grid $G --dry-run
python -m tools.strategy_farm.opt_census advance --ledger $L --param-grid $G
```

`report` is read-only; `advance --dry-run` shows the next transition without writing;
`advance` is safe to call repeatedly (idempotent). The factory dispatches the derived
runs through the normal worker path (`OPT_CENSUS` tier-6, never priority, metrics-isolated).

## Tests

```
test_opt_census.py .............. 12 passed   (sealing, Q02 precondition, matrix, idempotence)
test_opt_census_select.py ....... 15 passed   (threshold edge, activity-floor kill, ranking tie,
                                               ≤3 cap, stability pass/fail×2, plateau median,
                                               grid validation, trial-count-before-enqueue,
                                               advance idempotence, dry-run, full chain→READY_FOR_Q15)
test_opt_census_dispatch.py ..... 16 passed   (unchanged; dispatch/verdict/metrics isolation)
Package collect ................. 4135 tests, no import errors
```

Every expected value in `test_opt_census_select.py` is derived by hand arithmetic in a
comment beside the assertion so a reviewer can recompute it independently.

## Not in this task (handoff)

- F1 authors `opt_param_grid.json`; the schema above is the contract the driver validates.
- Live workers do not self-reload — the orchestrator restarts idle workers after commit
  for the new `advance`/`report` wiring to take effect.
- OWNER decision needed on the subset/superset wording flag before the pilot reaches the
  stability gate.
