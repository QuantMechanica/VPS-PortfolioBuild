# Slice b2_portfolio_caps — Portfolio caps as advisory diagnostics

Date: 2026-09-15
Decision authority: OWNER-DEC-CBE-20260915 (master directive §7, §8, §59; test list §70).
Audits consumed: `audit/rule_inventory_code.md` (F4/F5/F6, drift D1/D4), `audit/portfolio_engine_existing.md` (findings 6, 9; recommended Phase B actions).

## What this slice does

Converts the *static* portfolio concentration caps into advisory diagnostics inside the
existing portfolio package, while keeping the portfolio-LEVEL risk constraints as the only
hard guards. No new arbitrary permanent cap was invented (§8 final paragraph). The builders
remain deterministic (same inputs → same output; a determinism regression test was added).

1. **Per-dimension concentration caps → advisory** (`concentration_tail.py`). A breach of the
   symbol / asset_class / family / session percent-of-budget cutoff is now emitted as a
   structured `cap_warnings[]` entry (`cap`, `key`, `value`, `threshold`, `unit`, `severity`,
   `affected_sleeves`, `superseded_hard_cap`) instead of a `concentration_reject`. The
   percent-of-budget numbers themselves are unchanged and are kept as the warning thresholds.
   `concentration_reject` now carries ONLY the surviving hard guard: the portfolio-level
   joint-tail / venue-daily-loss limit (plus the fail-closed `data` guard in `unknown_report`).
   `builder_eligible`/`passed` are now driven by the hard guard, so a book that breaches a
   family/symbol cap builds (eligible) with a warning; a book that breaches the joint-tail
   guard still fails closed.

2. **DXZ builder** (`build_book_dxz.py`). `_final_status` now blocks only on hard-guard rejects
   (via `risk_diagnostics.hard_guard_rejects`), so a static-cap breach no longer forces
   `CONCENTRATION_CAP_BREACH`. A `risk_diagnostics` block is added to the manifest and to
   `analysis_summary`, and rendered in `evidence.md`.

3. **FTMO builder** (`build_book_ftmo.py`). The fixed pairwise-correlation cutoff in
   `select_under_aggregate_control` is now admit-with-WARN: a measured correlation at/above the
   cutoff is admitted (`ADMITTED_CORRELATION_WARN`) and recorded in `control.correlation_warnings`
   plus a `control.dependence_panel` (pairwise correlation per admitted pair). An UNMEASURED
   pairwise correlation stays `CLUSTER_CORRELATION_UNVERIFIED` fail-closed (§71). The
   `aggregate_correlation_and_risk_budget_control` bar no longer fails on a high-but-measured
   correlation; its surviving hard requirements are "every admitted pair has a measured
   correlation" + the account risk budget. The concentration bar check is renamed
   `concentration_tail_hard_guards` (still `concentration.builder_eligible`, now hard-guard-clean
   + OWNER-ratified policy). A `risk_diagnostics` block is added to the manifest and evidence.

4. **Dependence panel primitive** (`portfolio_correlation.py`). Added
   `dependence_panel_entry(...)` (pairwise correlation; downside correlation and trade overlap
   when the caller computes them; `severity` WARN at/above the advisory reference, `UNVERIFIED`
   when unmeasured). The Layer-A CI certifier (`_layer_a_verdict`) and `Q15_HARD_RULE_MAX_ABS_R`
   are UNCHANGED — the 0.50 stays a *measurement* band + advisory reference, not an admission gate
   (verdict semantics untouched).

5. **Shared diagnostics module** (`risk_diagnostics.py`, new). `split_rejects`,
   `hard_guard_rejects`, `cap_warnings`, `build`, `markdown`. Unknown reject dimensions are
   treated as HARD (fail-closed) rather than silently downgraded.

6. **FTMO probability contract** (`config/ftmo_probability_contract.v1.json`).
   - `tail.orthogonal_layers.q15_discrete_count_caps.status`: `OWNER_RATIFIED` → `ADVISORY`
     (+ `former_status`, `superseded_by: OWNER-DEC-CBE-20260915`, `advisory_note`). The
     `family_max: 3` / `symbol_max: 2` numbers are kept as warning thresholds. The stale
     `source` pointer (`build_book_ftmo.py:60,66` — actually FUND_SCORE_FLOOR + a comment that
     explicitly rejects a per-symbol/family count cap; audit drift D1) is corrected to
     `NOT_BUILDER_ENFORCED; origin decisions/2026-09-04_owner_receipts_briefing_2_4.md`.
   - `correlation.caps_absolute_layered.hard_book_admission.status`: `ROT_SEALED` → `ADVISORY`
     (+ `former_status`, `superseded_by`, `advisory_note`). **Value stays 0.50** (the contract
     parity test and `WORKING_DEFAULT_MAX_PAIRWISE_CORRELATION` read `.value`). Top-level
     contract keys, the INERT C-6 gate statuses, the P1 lower 0.80 and DSR N=369 are untouched,
     so the strict contract loader still validates.

## ROT_SEALED supersession record

The `hard_book_admission` correlation cutoff of **0.50 was marked `ROT_SEALED`**
(`portfolio_correlation.py:77`, contract `caps_absolute_layered.hard_book_admission`). Per the
directive, **OWNER-DEC-CBE-20260915 §8 supersedes it** as an absolute book-admission Hard Rule:
book admission is now admit-with-WARN with a dependence panel; portfolio-level risk is the
surviving hard guard. This is recorded in code comments (`portfolio_correlation.py`,
`build_book_ftmo.py`) and in the contract JSON `advisory_note`/`superseded_by` fields, and here.
`no_silent_reclassification` is satisfied: the reclassification cites the dated OWNER decision.

## Files changed

- `tools/strategy_farm/portfolio/risk_diagnostics.py` (new)
- `tools/strategy_farm/portfolio/concentration_tail.py`
- `tools/strategy_farm/portfolio/build_book_dxz.py`
- `tools/strategy_farm/portfolio/build_book_ftmo.py`
- `tools/strategy_farm/portfolio/portfolio_correlation.py`
- `tools/strategy_farm/config/ftmo_probability_contract.v1.json`
- `tools/strategy_farm/tests/test_concentration_tail.py`
- `tools/strategy_farm/tests/test_dual_book_builders.py`
- `docs/ops/evidence/2026-09-15_continuous_book_evolution/design/b2_portfolio_caps_report.md` (this file)

## Contracts changed (regression-tested per §70)

- `qm.concentration-tail-report/v1`: adds `cap_warnings[]`; `concentration_reject` restricted
  to hard guards (`joint_tail`/`data`); `builder_eligible`/`passed` driven by hard guard.
- Dual-book manifest (`qm.dual-book-manifest/v1`): adds `risk_diagnostics` (allowed by the
  schema's top-level `additionalProperties: true`; status enum unchanged — the surviving
  hard-guard breach still uses `CONCENTRATION_CAP_BREACH`).
- FTMO builder selector: `ADMITTED_CORRELATION_WARN` reason + `correlation_warnings`/
  `dependence_panel` in the control summary; bar check renamed `concentration_tail_hard_guards`.
- `ftmo_probability_contract.v1.json`: `q15_discrete_count_caps` and `hard_book_admission`
  reclassified to `ADVISORY`.
- New primitive `portfolio_correlation.dependence_panel_entry`.

## Tests added

`test_concentration_tail.py`:
- `test_three_sleeves_same_symbol_trigger_d1_advisory_warning` (was `..._reject`)
- `test_family_cap_breach_is_advisory_and_book_still_builds`
- `test_portfolio_joint_tail_guard_still_fails_closed`

`test_dual_book_builders.py`:
- `test_dxz_final_status_only_blocks_on_hard_portfolio_guard` (was `..._spc3_gate_precedes...`)
- `test_ftmo_aggregate_control_admits_high_corr_with_warn_and_panel_entry` (was `..._excludes...`)
- `test_ftmo_aggregate_control_admits_high_negative_absolute_correlation_with_warn` (was `..._rejects...`)
- `test_ftmo_aggregate_control_is_deterministic_under_warn_admission`
- `test_ftmo_unverified_correlation_still_fails_closed_under_advisory_regime`
- `test_risk_diagnostics_surface_cap_warnings_and_hard_guards`

### Test result (pytest summary lines)

```
tools/strategy_farm/tests/test_dual_book_builders.py test_concentration_tail.py test_ftmo_probability_contract.py
  38 passed, 1 skipped, 1 warning in 2.97s
tools/strategy_farm/tests/test_portfolio_correlation.py test_build_book_dxz_grid_union.py
  13 passed in 1.24s
tools/strategy_farm/tests (test_book_build_guard, test_book_path_refusal_cli, test_ftmo_cost_version,
  test_portfolio_periodic_report, test_portfolio_q08_contribution, test_review_repair,
  test_risk_freeze_prevention, test_sparse_d1_orthogonality)
  87 passed, 1 skipped, 1 warning in 8.93s
```

## Rollback

- `git revert` the slice commit. All changes are additive/behavioural in dry-run book builders
  (application stays OWNER_ONLY); reverting restores the hard-reject semantics.
- No environment flag gates this slice. To restore the old hard behaviour without a full revert,
  a follow-up could re-add the advisory dimensions to `concentration_tail`'s hard `rejects` and
  restore the `CLUSTER_CORRELATION_EXCLUDED` branch in `build_book_ftmo.py` — but that would
  re-litigate an OWNER-final decision (§8) and is not recommended.

## Items NOT done (with exact reason)

- **`book_reoptimizer.py --max-corr 0.50` greedy selection** (`book_reoptimizer.py:6,91`,
  audit F6): NOT in this slice's named files (§8 slice names `build_book_ftmo.py` and
  `portfolio_correlation.py`). The greedy reoptimizer's pairwise cutoff is left unchanged;
  it is a separate selection tool, not the book-admission path. Flagged for a follow-up slice.
- **Downside correlation / trade-overlap population in the dependence panel**: the primitive
  (`dependence_panel_entry`) accepts `downside_correlation` and `trade_overlap`, but the FTMO
  builder currently populates only pairwise correlation (that is what the aggregate selector
  measures today). Computing downside correlation / trade overlap from the return series /
  overlap primitive for the panel is left to the Phase-E recomposition `metrics.py` work
  (audit portfolio_engine_existing.md recommendation), to avoid heavy recomputation in the
  admission selector and keep this slice minimal and deterministic.
- **DXZ dependence panel**: the DXZ builder does not apply a pairwise-correlation admission
  cutoff (that lives in `book_reoptimizer.py`), so its `risk_diagnostics.dependence_panel` is
  empty; DXZ carries the concentration `cap_warnings` + hard-guard summary. Full DXZ pairwise
  dependence belongs to the Phase-E engine.
