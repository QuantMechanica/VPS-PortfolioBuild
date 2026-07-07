# c050d3e0 DWX History Registry Unblock

Task: `c050d3e0-e47b-4fd9-aade-45283d359825`

## Change

- Added `infra/scripts/build_dwx_history_ranges.py` to regenerate `framework/registry/dwx_symbol_history_ranges.csv` from MT5 `.hcc` custom-symbol history.
- Regenerated the registry for 37 canonical DWX symbols and 19 supported periods: `D1,H12,H8,H6,H4,H3,H2,H1,M30,M20,M15,M12,M10,M6,M5,M4,M3,M2,M1`.
- Left `W1` and `MN1` excluded. No W1/MN1 relaxation was made.
- Populated `source_terminals` from numeric factory terminals only (`T1` through `T10`) that cover the selected contiguous `.hcc` year range.

Regeneration log: `docs/ops/evidence/c050d3e0_dwx_history_registry_regen_2026-07-07.json`

## Empirical Data

No new MT5 terminal was launched in this headless cycle because the orchestration hard rule says never start `terminal64.exe` manually. Instead, I used existing completed work-item reports and tester-cache evidence for the exact derived-period classes.

| Period | Symbol | EA | Phase | Verdict | Bars | Trades | Report |
| --- | --- | --- | --- | --- | ---: | ---: | --- |
| M30 | NDX.DWX | QM5_10805 | Q02 | PASS | 70,556 | 1,839 | `D:\QM\reports\work_items\aef06360-b6ca-420e-ac00-343ddd11f8a8\QM5_10805\20260704_125315\raw\run_01\report.htm` |
| H8 | XAUUSD.DWX | QM5_10494 | Q03 | PASS | 774 | 96 | `D:\QM\reports\work_items\4fcc9a17-9dcb-428a-bf3f-a76cb25ac76c\QM5_10494\20260701_144855\raw\run_01\report.htm` |
| M1 | GBPUSD.DWX | QM5_10502 | Q02 | PASS | 1,840,574 | 1,359 | `D:\QM\reports\work_items\d62c78b9-0109-40f5-8487-1f7ad515709b\QM5_10502\20260627_162251\raw\run_01\report.htm` |
| M30 | WS30.DWX | QM5_10396 | Q02 | FAIL | 5,935 | 0 | `D:\QM\reports\work_items\7f55d701-bd80-497c-8d7a-a12e20451637\QM5_10396\20260704_231333\raw\run_01\report.htm` |

All four reports show `100% real ticks`. The WS30 row is a strategy FAIL, not an infra/history failure: it produced a valid report with real bars/ticks and zero trades.

Detailed CSV: `docs/ops/evidence/c050d3e0_dwx_history_empirical_runs_2026-07-07.csv`

## Queue Effect

Snapshot source: `D:\QM\strategy_farm\state\farm_state.sqlite`, queried with the canonical `C:/QM/repo` worker code.

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| Pending Q02/P2 rows | 5,499 | 5,499 | 0 |
| History-blocked rows | 437 | 119 | -318 |
| History-ok rows | 5,062 | 5,380 | +318 |
| Claimable ignoring multisymbol/terminal-busy gates | 2,325 | 2,430 | +105 |

Non-writing worker simulation for `T9` after the registry change found a claimable row after scanning 16 priority rows:

- `a9e1d513-9f3-4391-b61a-2fe4e2dbf34a`
- `QM5_1118`, `CHFJPY.DWX`, `Q02`, `M1`

Before/after and residual breakdown CSV: `docs/ops/evidence/c050d3e0_dwx_history_claimability_before_after_2026-07-07.csv`

## Residual Blockers

The 119 remaining history-blocked rows are not solved by derived-period expansion:

- W1/MN1 remain blocked by design.
- Non-canonical or unavailable symbols remain blocked, led by `GER40.DWX` (56), `XBRUSD.DWX` (18), and `JPN225.DWX` (4).
- Some canonical rows still fall outside the conservative contiguous-year range and should be handled by explicit requeue/invalid decisions, not silent registry widening.

No work-item status was mutated in this cycle.

## Verification

- `python infra/scripts/build_dwx_history_ranges.py --mt5-root D:\QM\mt5 --symbol-matrix framework\registry\dwx_symbol_matrix.csv --out-csv framework\registry\dwx_symbol_history_ranges.csv --out-summary docs\ops\evidence\c050d3e0_dwx_history_registry_regen_2026-07-07.json`
- `python -m unittest tools.strategy_farm.tests.test_dwx_history_ranges_builder`
- Non-writing SQLite claimability probe against `D:\QM\strategy_farm\state\farm_state.sqlite`.
