# c050d3e0 DWX History Registry Unblock

Task: `c050d3e0-e47b-4fd9-aade-45283d359825`

## Change

- `fd5764642 ops: expand DWX history registry periods` added `infra/scripts/build_dwx_history_ranges.py` and regenerated `framework/registry/dwx_symbol_history_ranges.csv` from MT5 `.hcc` custom-symbol history.
- Registry now covers 37 canonical DWX symbols and 19 supported MT5-derived periods: `D1,H12,H8,H6,H4,H3,H2,H1,M30,M20,M15,M12,M10,M6,M5,M4,M3,M2,M1`.
- `W1` and `MN1` remain excluded. There are 0 `W1`/`MN1` rows in the registry.
- This cycle added a worker claim fix: when the history guard adjusts a default request such as 2017-2022 to the registry range, `terminal_worker.claim_atomic()` now persists `from_year`, `to_year`, `history_first_year`, `history_last_year`, and `history_adjusted` into the payload before launch. That prevents legacy pending rows from being claimed as valid and then run over an unavailable 2017 slice.

Regeneration log: `docs/ops/evidence/c050d3e0_dwx_history_registry_regen_2026-07-07.json`

## T9 Canaries

All runs used `framework/scripts/run_smoke.ps1`, `Terminal=T9`, `Model=4`, `Runs=1`, `MinTrades=0`, `SmokeMode`. T9 had no running terminal before/after the canaries.

| Class | Period | Symbol | EA | Window | Result | Bars | Trades | Report |
| --- | --- | --- | --- | --- | --- | ---: | ---: | --- |
| Derived period | M30 | AUDUSD.DWX | QM5_10012 | 2024.07.01-2024.07.31 | PASS | 1,055 | 22 | `D:\QM\reports\c050d3e0_history_canary\QM5_10012\20260707_134242\raw\run_02\report.htm` |
| Derived period | H8 | EURJPY.DWX | QM5_10574 | 2024.07.01-2024.07.31 | PASS | 66 | 22 | `D:\QM\reports\c050d3e0_history_canary\QM5_10574\20260707_134822\raw\run_01\report.htm` |
| Derived period | M1 | EURAUD.DWX | QM5_1118 | 2024.07.01-2024.07.07 | PASS | 7,143 | 26 | `D:\QM\reports\c050d3e0_history_canary\QM5_1118\20260707_135016\raw\run_01\report.htm` |
| Adjusted window | D1 | WS30.DWX | QM5_10020 | 2018.07.02-2018.12.31 | PASS | 27 | 0 | `D:\QM\reports\c050d3e0_history_canary\QM5_10020\20260707_135039\raw\run_01\report.htm` |

Detailed canary CSV: `docs/ops/evidence/c050d3e0_dwx_history_canary_results_2026-07-07.csv`

Earlier completed-report evidence remains in `docs/ops/evidence/c050d3e0_dwx_history_empirical_runs_2026-07-07.csv`.

## Queue Effect

Original non-writing probe against `D:\QM\strategy_farm\state\farm_state.sqlite`:

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Pending Q02/P2 rows | 5,499 | 5,499 | 0 |
| History-blocked rows | 437 | 119 | -318 |
| History-ok rows | 5,062 | 5,380 | +318 |
| Claimable ignoring multisymbol/terminal-busy gates | 2,325 | 2,430 | +105 |

Before/after CSV: `docs/ops/evidence/c050d3e0_dwx_history_claimability_before_after_2026-07-07.csv`

Current residual/action snapshot after the registry commit and this cycle:

- `REQUEUE_NOT_NEEDED__CLAIM_PAYLOAD_ADJUSTS_TO_REGISTRY_WINDOW`: 1,272 rows. The worker now clamps these at claim time.
- `KEEP_BLOCKED_UNSUPPORTED_PERIOD__NO_RELAX_W1_MN1`: 34 rows.
- `KEEP_BLOCKED_NO_REGISTRY_SYMBOL_PERIOD__NEEDS_ALIAS_OR_INVALID_REVIEW`: 85 rows, led by `GER40.DWX`, `XBRUSD.DWX`, and `JPN225.DWX`.

Residual/action CSV: `docs/ops/evidence/c050d3e0_dwx_history_invalid_requeue_breakdown_2026-07-07.csv`

No W1/MN1 relaxation, no gate criteria change, and no broad work-item invalidation/requeue mutation were performed in this cycle.

## Verification

- `python infra/scripts/build_dwx_history_ranges.py --out-csv $env:TEMP\dwx_symbol_history_ranges_check.csv --out-summary $env:TEMP\dwx_symbol_history_ranges_check.json`
- `Compare-Object` between the generated temp CSV and `framework/registry/dwx_symbol_history_ranges.csv`: no differences.
- Registry row count: 704 file lines including header; 0 matches for `,W1,|,MN1,`.
- `python -m unittest tools.strategy_farm.tests.test_dwx_history_ranges_builder`
- `python -m unittest tools.strategy_farm.tests.test_dwx_history_range_filter`
- `python -m unittest tools.strategy_farm.tests.test_terminal_worker_atomic_claim.TerminalWorkerAtomicClaimTests.test_q02_claim_persists_adjusted_history_window tools.strategy_farm.tests.test_terminal_worker_atomic_claim.TerminalWorkerAtomicClaimTests.test_q02_claim_skips_terminal_without_symbol_history_source tools.strategy_farm.tests.test_terminal_worker_atomic_claim.TerminalWorkerAtomicClaimTests.test_dwx_history_range_registry_is_respected_for_p2_claims`
