# Q08 parameter-type-aware neighborhood / PBO repair

**Date:** 2026-07-17
**Router task:** `032d28e1-0ebd-44d5-947d-21de027ba8d9`
**State requested after this packet:** `REVIEW`
**Implementation commit:** `6f02e31f5` (`main`)
**QM5_13301 source-lineage repair:** `b787a76cd` (`agents/board-advisor`)
**OWNER specification source:** `4e32668a0` (`agents/board-advisor`)

## Review verdict

The Q08.5 neighborhood and Q08.7 PBO tooling defect is repaired at code level and is ready for review. The runner now builds complete, distinct, parameter-type-aware setfiles; binds each result to the exact fresh child summary; treats zero-trade cells as INVALID rather than breaches; and gives PBO at least two verified configurations when valid neighborhood runs exist.

This packet does **not** assert new pipeline verdicts for the four target EAs. No target Q08 phase was rerun during this scheduled orchestration cycle because T1-T7 were active and the operator contract forbids interrupting active terminals or manually starting `terminal64.exe`. Schema-v2 target evidence must therefore be produced by an authorized, terminal-safe Q08 rerun after the implementation is deployed.

## Defects closed

1. The phase dispatcher did not pass the exact work-item baseline setfile into Q08, allowing guesswork and stale lineage.
2. The legacy set generator could drop or empty strategy inputs while applying an override.
3. Every non-zero numeric input was treated as continuously perturbable, including fitted coefficients and calendar lattice values.
4. The child backtest used weak/stale summary discovery and could associate one perturbation with another run's output.
5. Zero-trade perturbations could be counted as robustness breaches instead of tooling-invalid cells.
6. Q08.7 could treat repeated evidence for one effective setfile as multiple configurations and publish a vacuous one-config family.
7. Cached neighborhood/PBO artifacts lacked sufficiently strict schema, engine, setfile, parameter-source, and freshness checks.

## Implemented behavior

- `farmctl` now forwards `work_items.setfile_path` and a bounded two-parameter neighborhood cap to the Q08 aggregate runner.
- The aggregate runner uses the explicit setfile, resolves basket host symbol/history context, budgets the complete child-run timeout, quarantines stale evidence, refreshes PBO, and fails closed when post-run lineage is not reusable.
- The neighborhood runner parses only the strategy block, rejects missing/duplicate/empty assignments, preserves the full parameter inventory and optimiser lattice, and validates every generated override.
- Continuous knobs use ±10% with declared step alignment and a real minimum ±1 move for integer inputs.
- Calendar/ordinal inputs use ±1 lattice steps. Fitted `beta`/hedge-ratio/regression/PCA inputs are excluded. Framework/risk/news/portfolio inputs are never perturbed.
- Each child result must be linked through the fresh `run_smoke` output marker and match EA, expert, symbol, period, terminal, and start time. Missing metrics or zero trades produce `status=INVALID` with a reason.
- Neighborhood evidence is published atomically as schema v2 only after the run completes. At least two valid perturbations are required for usable evidence.
- PBO configuration identity is the canonical active strategy assignment set, not a work-item ID or comment/header hash. Valid, distinct neighborhood summaries are used when the Q03 family is not evaluable.
- PBO schema-v2 metadata explicitly publishes `VALID`, `INVALID`, or `INVALID_NA`; the sub-gate consumes that state instead of calculating on an invalid file.
- A valid perturbation with PF ≤ 1.0 or DD above 1.5× baseline remains a hard neighborhood breach. Invalid cells are logged and excluded, while a valid breach still dominates them.

## Target-specific static verification

The patched parser, classifier, setfile materializer, and canonical active-config hasher were run against the exact current work-item setfiles. Each check created a nominal file plus four perturbation files in a temporary directory, re-parsed every file, verified unchanged parameter inventory/lattice, and required five distinct non-null effective configuration hashes.

| Target | Source and classification result | Verified configs | Current pipeline evidence status |
|---|---|---:|---|
| QM5_13117 | 7 strategy inputs; 6 perturbable. `strategy_beta` is `structural` with no candidates. `atr_period_d1` emitted 18/22 and `atr_sl_mult` emitted 1.8/2.2. | 5 | Current `perturbations.json` is missing; latest Q08 attempt timed out after quarantining legacy evidence. No new verdict claimed. |
| QM5_13301 / GDAXI | The source setfile incorrectly declared `GBPJPY.DWX`; this exact fail-closed rejection appears in the latest Q08 aggregate. Commit `b787a76cd` corrects the declaration to `GDAXI.DWX` while retaining `RISK_FIXED=1000`, `RISK_PERCENT=0`. After repair, 11 inputs were parsed; `atr_period` emitted 13/15 and discrete `exit_hour` emitted 19/21. | 5 | Current neighborhood/PBO artifacts are missing. No new verdict claimed. |
| QM5_10513 | Latest Q08 work-item setfile parsed 7 strategy inputs and 6 valid perturbable knobs. `atr_period` emitted 14/18 and `atr_sl_mult` emitted 1.0562238/1.2909402. | 5 | Existing artifact is legacy and has a zero-trade baseline; it is not schema-v2 evidence. No new verdict claimed. |
| QM5_10476 / USDCAD | 11 strategy inputs; `ao_fast_period` emitted 4/6 and `ao_slow_period` emitted 31/37. | 5 | Historical evidence records baseline DD 13967.4 and valid `ao_slow_period -10%` DD 22190.52 (ratio 1.588737), the reference true breach. The regression test preserves FAIL semantics, but a schema-v2 rerun is still required before stating a current pipeline verdict. |

## Focused verification

All successful commands were run from `C:\QM\worktrees\cto_main`:

```text
python -m pytest framework/scripts/tests/test_q08_davey_subgates.py -q
61 passed

python -m pytest framework/scripts/tests/test_pbo_calculator.py tools/strategy_farm/tests/test_cascade_real_phase_runners.py -q
8 passed

python -u -m pytest tools/strategy_farm/tests/test_farmctl_cascade.py -vv -s --tb=short
20 passed, 4 subtests passed

python -m py_compile framework/scripts/q08_5_neighborhood_runner.py framework/scripts/q08_7_pbo_runner.py framework/scripts/q08_davey/aggregate.py framework/scripts/q08_davey/sub_8_5_neighborhood.py framework/scripts/q08_davey/sub_8_7_pbo.py tools/strategy_farm/farmctl.py
PASS

git diff --check
PASS
```

The tests cover structural beta exclusion, continuous ±10% behavior, calendar ±1 behavior, optimiser-step alignment, complete setfile materialization, zero-trade INVALID semantics, the PF=1.0 boundary, true-breach dominance, exact fresh-summary identity, schema/engine/setfile/parameter-source cache lineage, fresh PBO publication, active-config deduplication, one-config rejection, neighborhood fallback, and exact Q08 dispatcher arguments.

## Guardrail audit

- No `qm_news_stale_max_hours` setting was changed.
- No news seed or news fail-closed behavior was changed.
- All inspected target setfiles retain `RISK_FIXED > 0` and `RISK_PERCENT = 0`.
- No `T_Live`, AutoTrading, or terminal setting was changed.
- No terminal was started manually and no active T1-T10 backtest was interrupted.
- All operator-facing phase references remain Q-series.
- No pipeline PASS/FAIL was inferred from unit or static evidence.

## Required post-review verification

After deployment and when an authorized terminal is available, execute fresh Q08 work items for QM5_13117, QM5_13301/GDAXI, and QM5_10513, plus the QM5_10476/USDCAD regression reference. Acceptance requires current schema-v2 neighborhood and PBO artifacts with exact lineage. Expected shapes are:

- QM5_13117: beta excluded; at least two valid real-knob perturbations; Q08.5 and Q08.7 become evaluable.
- QM5_13301: corrected GDAXI lineage yields a non-null baseline and valid perturbation family.
- QM5_10513: baseline is non-degenerate and the perturbation family has at least two valid configurations.
- QM5_10476: the valid DD breach remains a blocking Q08.5 FAIL.

Those outcomes are pending pipeline evidence and are intentionally not represented as completed verdicts in this packet.
