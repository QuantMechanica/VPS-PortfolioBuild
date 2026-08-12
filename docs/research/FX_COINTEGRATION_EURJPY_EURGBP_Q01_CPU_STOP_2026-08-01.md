# QM5_20197 EURJPY/EURGBP Cointegration — Q01 Build and CPU Stop

Date: 2026-08-01
Branch: `agents/board-advisor`

## Outcome

`QM5_20197_eurjpy-eurgbp` is a new, non-duplicate, low-frequency D1 FX
basket. The approved card, deterministic registry allocation, two traded
magic rows, EA, RISK_FIXED setfiles, and basket manifest are complete. Q01
passes. Q02 was not enqueued because the paced-fleet CPU ceiling was binding.

The two anchor baskets did not need Q02 repair: `QM5_12532` has canonical Q02
PASS followed by Q05 FAIL, while `QM5_12533` has canonical Q02 PASS followed
by Q04 FAIL.

## Selection and Source Boundary

The checked-in sign-aware reproduction of the fixed 66-pair scan ranked
EURJPY/EURGBP fifteenth by OOS net Sharpe. Rank 14 NZDUSD/EURJPY is already
built as `QM5_12723` and has terminal Q02 PASS evidence. Repository searches
found no dedicated fixed-beta EURJPY/EURGBP D1 card, EA, or logical manifest.

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURJPY / EURGBP | 0.717918 | 0.646491 | 8.050213% | 20 | -0.679904414 | 83.425 D1 bars |

The sub-0.8 OOS Sharpe and slow half-life are adverse evidence. The approved
card authorizes a one-shot frontier test and requires retirement on terminal
economic failure or sub-floor cadence. It forbids a filter, beta refit, or
parameter rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

Chan supplies the reputable structural pair-trading method and makes no
performance claim for EURJPY/EURGBP.

## Mechanization

- Host/traded leg: `EURJPY.DWX`, magic `201970000`
- Companion/traded leg: `EURGBP.DWX`, magic `201970001`
- Conversion-history only: `USDJPY.DWX`, `GBPUSD.DWX`, and `EURUSD.DWX`
- Fixed spread: `ln(EURJPY) - (-0.679904414) * ln(EURGBP)`
- Signal: strictly prior 60-bar closed-D1 z-score
- Entry/exit: `abs(z) > 2.0` / `abs(z) < 0.5`
- Negative-beta direction: long spread buys both legs; short spread sells both
- Risk stop: `ATR(20, D1) * 2.0` per traded leg
- Package safety: both normalized volumes are preflighted; partial entry and
  orphan states are flattened
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Tester account: USD 100,000; all five required histories are in
  `basket_manifest.json`

## Q01 Evidence

- Strategy Card schema lint: PASS, no ML hits
- G0 structural lint: PASS; card status `APPROVED`
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- MetaEditor compile: PASS, zero errors and zero warnings
- SPEC validation: PASS
- Symbol-scope validation: `BASKET_OK`, zero violations
- Targeted basket-manifest regression: PASS
- Magic resolver: 15,382 rows kept, zero dropped under `--keep-obsolete`
- Final EX5 SHA-256:
  `25178a6c76f7d390570a9cde63d87afb8029cdfa6e623ea727b6cf8b3746d426`
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_164231.json`
- Compile summary:
  `D:\QM\reports\compile\20260801_164231\summary.csv`

No manual smoke, tester, or backtest run was launched.

## Q02 CPU-Ceiling Stop

At `2026-08-01T16:43:30Z`, the path-aware factory scan found exactly seven
running factory terminals:

```text
T1, T2, T4, T5, T7, T9, T10
```

Seven equals the paced-fleet ceiling. `T_Live` was observed separately and
excluded from the factory count; it was not controlled. A final read-only
work-item query returned zero rows for `QM5_20197`. Per the mission's explicit
CPU-ceiling stop, no Q02 row, manual dispatch, tester launch, or terminal
action followed.

Machine-readable snapshot:
`artifacts/fx_cointegration_q01_cpu_stop_20260801T164330Z_board_advisor.json`.

## Safety

- No portfolio admission, portfolio KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, AutoTrading state, or live setfile changed.
- No manual backtest, process control, or live action occurred.
