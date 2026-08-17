# Q02 basket budget and QM5_41030 incremental-flow repair

- Router task: `d8fb0b43-8bb4-4184-912d-7cdd171fad63`
- Cycle time: 2026-08-17 UTC
- Operator: Codex
- Scope: Q02 only; no terminal was started or interrupted and no pipeline verdict is asserted.

## Budget policy

The Q02 logical-basket timeout now uses a member-aware floor while retaining the hard 25,200-second cap:

`min(25,200, 14,400 + 400 * (member_count - 2))` for two or more members.

This yields 14,400 seconds for a two-member basket, 17,200 for nine members, and 24,800 for 28 members. Single-symbol behavior remains 7,200 seconds. Prescreen estimates cannot raise a basket above 25,200 seconds, and a payload override above the cap remains clamped.

The stranded-Q02 sweep now recognizes consecutive clean logical-basket deaths at the granted wall. Two consecutive exact wall deaths park the pair under `BASKET_BUDGET_WALL_REPEAT` instead of creating another successor. The classifier refuses ambiguous rows and excludes INIT failures, log bombs, model-4 failures, mixed reason classes, multi-attempt summaries, and rows whose elapsed time is not within one percent of the granted timeout. No existing parked cohort was requeued by this task.

## QM5_41030 repair

The EA previously issued two six-bar `CopyRates` calls inside every strategy decision. The repair loads the same six closed daily bars once, then rolls the cache by one closed bar on each new host D1 bar. A missed-anchor check falls back to a full six-bar refresh. Signal thresholds, Monday gating, bar indexes, arithmetic, and direction rules are unchanged.

The decision-identity test evaluates the old direct-read model and the new rolling-cache model across a deterministic 90-day two-leg series. All Monday decisions and relative-flow values are identical. It also checks that the strategy decision function contains no `CopyRates` call and that the rolling path fetches one closed bar per leg.

Compile result for `QM5_41030_xauxag-flowdiv`: 0 errors, 0 warnings, `BASKET_OK`. The current EX5 SHA-256 is `2815cb12125877db6cab46e12ba9fd860f799802e1c080201c4d2fddd13cdb50`.

## Focused verification

Command:

`python -m pytest -q tools/strategy_farm/tests/test_smoke_timeout_override.py tools/strategy_farm/tests/test_p2_prescreen_policy.py tools/strategy_farm/tests/test_sweep_enqueue_built_eas.py tools/strategy_farm/tests/test_qm5_41030_incremental_flow.py`

Result: 23 tests passed plus 10 subtests.

`git diff --check` and Python bytecode compilation also passed for the edited sources.

## Governed canary admission

The existing Q02 row `c2636b77-481e-426c-b0e8-15623c25468c` was still pending, unclaimed, attempt zero, and protected by the exact `BASKET_BUDGET_CAP_EXCEEDED` hold. After compile and decision-identity proof, an atomic compare-and-swap operation:

1. backed up the farm database to `D:\QM\strategy_farm\state\backups\farm_state_before_qm5_41030_performance_repair_20260817_084333.sqlite`;
2. rebound the row to the exact current MQ5, EX5, setfile, expert, symbol, and period identities;
3. verified `RISK_FIXED > 0` and `RISK_PERCENT = 0`;
4. recorded a `governed_hold_released` event; and
5. released only the named hold with a performance-repair release note.

Postcondition: the row is pending, unclaimed, attempt zero, authenticated to the EX5 SHA above, and no longer held. The normal scheduled worker owns execution. This single-pass orchestration cycle does not wait for a multi-hour Q02 result; measured runtime and any Q02 verdict must come from the worker's eventual report.
