# Cross-reference for agent-34 — Q08 DSR remainder cohort audit

From: `d1-failure-analysis` (2026-09-16). Companion analysis: `ANALYSIS.md` in this directory
(`docs/ops/evidence/2026-09-16_d1_failure_analysis/`).

## What we found on the repaired V3 Q08 cohort (16 NDX/GDAXI D1/H1 rows, 13 executed:
## 11× FAIL_HARD, 1× FAIL_SOFT, 1× INVALID)

1. **Universal hard cause = §8.2 DSR MC FDR** (p 0.089–1.000, thr 0.05) in 11/11 FAIL_HARD rows;
   sole hard cause in 8. DSR here is NOT multiplicity-harsh: effective_trial_count=1,
   `selection_correction_applied=false` — rows fail on raw daily Sharpe ≤ 0.022 (ann ≤ 0.42)
   over 3,287 days. Expect the same signature in the DSR remainder cohort.
2. **Setfile artifact defect is real but verdict-neutral for FAIL_HARD**: 8/13 rows have
   `empty_strategy_params` setfiles → §8.5/§8.7 INVALID (`baseline setfile has no strategy
   parameters`, `insufficient_distinct_configs:got=0`). It never appears in `hard_causes`; rows
   with complete §8.5/§8.7 evidence fail identically; DL082 ext-option-D requires §8.2 PASS so it
   can never rescue an §8.2 EDGE_HARD. Its only verdict effect is exclusion (10211 → INVALID
   despite DSR p=0.010).
3. **Checklist for your audit** (per row):
   - Read `aggregate.json` → `dl082_ext_option_d_detail.hard_causes`. If 8.2 dominates, it is
     economics, even if §8.5/§8.7 are INVALID.
   - Verify the §8.2 evidence block: `effective_trial_count`, `selection_correction_applied`,
     `sharpe_daily`, `dsr_p`. If trial_count=1, the gate is lenient, not harsh.
   - Check the row's setfile for the `empty_strategy_params` defect before attributing INVALID
     sub-gates to infra: marker `; strategy-specific params` followed by zero `strategy_*` rows.
   - `_guess_baseline_setfile` (framework/scripts/q08_davey/aggregate.py:580) does not exclude
     `ablation_*` files — a row can get §8.5 evidence via glob-order luck even with an EMPTY
     nominal setfile (10804 did). Don't read §8.5 PASS as "setfile healthy".
4. **Do not recommend Q08 recalibration on DSR grounds** without rows that fail §8.2 with
   ann. Sharpe ≥ ~0.5 AND complete evidence — none exist in our cohort.
5. Related artifacts: `tools/strategy_farm/backfill_setfile_strategy_params.py` (fix tooling +
   defect scale note), `docs/ops/evidence/2026-09-05_q08_empty_strategy_params_11179.md`,
   `decisions/2026-07-25_q08_tooling_invalid_is_infra.md`.
