# QM5_20183 GBPUSD/USDCHF Cointegration Q02 Handoff

Date: 2026-07-31

Branch: `agents/board-advisor`

State: `Q02_READY` (not enqueued because the factory was above its CPU ceiling)

## Selection

`GBPUSD.DWX` / `USDCHF.DWX` was the highest OOS-ranked sign-aware row from the
66-pair FX cointegration scan without a dedicated cointegration card or EA.
The fixed scan specification produced:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| GBPUSD / USDCHF | -0.374993 | 0.939211 | 5.182890% | 14 | -0.651268047 | 116.976 D1 bars |

The negative DEV result is preserved as adverse evidence. The approved card
requires retirement on a terminal economic failure or sub-floor cadence and
forbids a post-failure filter/refit rescue.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

## Build

- EA ID: `20183`
- EA label: `QM5_20183_gbpusd-chf-coint`
- Logical symbol: `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`
- Host: `GBPUSD.DWX`, D1
- Second leg: `USDCHF.DWX`
- Magic slots: `201830000`, `201830001`
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Basket manifest: present, USD tester currency, USD 100,000 deposit
- Live artifacts: none

The implementation uses a fixed negative hedge ratio. A long spread buys both
legs and a short spread sells both legs, partially offsetting the common USD
exposure. The score uses the newest closed spread against a strictly prior
60-bar calibration window. Entry is at `abs(z) > 2.0`, package exit is at
`abs(z) < 0.5`, and both legs have `ATR(20) * 2.0` hard stops plus partial-entry
rollback and orphan cleanup.

## Validation

- Card schema lint: PASS
- G0 card lint: PASS
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- Compile: PASS, zero errors and zero warnings
- Symbol-scope validator: `BASKET_OK`, zero violations
- Targeted basket manifest/RISK_FIXED regression test: PASS
- Final build report:
  `D:\QM\reports\framework\21\build_check_20260731_084552.json`
- Final compile summary:
  `D:\QM\reports\compile\20260731_084553\summary.csv`

The repository-wide registry validator remains red on pre-existing legacy
inventory defects. The new ID, two magic rows, generated resolver entries, and
EA build guard are internally consistent.

## CPU Ceiling

At the final capacity check, the canonical farm database reported:

- `active=9`
- `pending=2230`
- eight factory `terminal64.exe` processes on T1/T2/T4/T6/T7/T8/T9/T10
- T_Live present but untouched and excluded from factory capacity

The documented ceiling is seven factory backtests. No Q02 work item, smoke
test, backtest, terminal launch, T_Live change, portfolio-gate change, or live
manifest change was made. Enqueue the single logical-basket Q02 only after
active factory load is below the ceiling.
