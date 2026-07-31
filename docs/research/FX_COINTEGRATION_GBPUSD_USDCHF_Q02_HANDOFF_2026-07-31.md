# QM5_20183 GBPUSD/USDCHF Cointegration Q02 Handoff

Date: 2026-07-31

Branch: `agents/board-advisor`

State: `Q02_FAIL_TERMINAL` (logical-basket work item
`564a8012-bb2b-4edf-a9f1-acd04b177d64`; retirement evidence:
`docs/ops/evidence/2026-07-31_qm5_20183_q02_terminal_retirement.md`)

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

At the pre-commit capacity check, the canonical farm database reported:

- `active=9`
- `pending=2230`
- eight factory `terminal64.exe` processes on T1/T2/T4/T6/T7/T8/T9/T10
- T_Live present but untouched and excluded from factory capacity

A post-commit read-only confirmation reported `active=8`. Both observations
were above the ceiling.

The documented ceiling is seven factory backtests. No Q02 work item, smoke
test, backtest, terminal launch, T_Live change, portfolio-gate change, or live
manifest change was made. Enqueue the single logical-basket Q02 only after
active factory load is below the ceiling.

## Q02 Enqueue

At `2026-07-31T11:24:14+02:00`, a fresh path-aware scan found five factory
terminals (`T1`, `T2`, `T6`, `T8`, and `T10`) against the seven-terminal
ceiling. The separate pre-existing T_Live process was excluded, and
`FACTORY_OFF.flag` was absent. The canonical farm still had zero work items
for `QM5_20183`.

The targeted governed sweep then created exactly one Q02 work item:

- Work item: `564a8012-bb2b-4edf-a9f1-acd04b177d64`
- Symbol: `QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1`
- Setfile:
  `QM5_20183_gbpusd-chf-coint_QM5_20183_GBPUSD_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Immediate status: `pending`, attempt 0, unclaimed
- Enqueued at: `2026-07-31T11:24:26+02:00`

The manifest host remains `GBPUSD.DWX` D1 with `USDCHF.DWX` as the companion
leg, USD tester currency, USD 100,000 deposit, and `RISK_FIXED=1000`.
The legacy physical-host setfile was explicitly skipped. No tester was
manually launched and no Q02 verdict is claimed.

## Q02 Terminal Verdict

The paced worker subsequently completed the single logical-basket row with a
terminal `FAIL`. The report recorded 8 trades, profit factor 0.82, net profit
-243.26, and `MIN_TRADES_NOT_MET` across 2018-07-02 through 2022-12-31. It
recorded no `ONINIT` failure and no history/setup reason class. Per the card's
predeclared retirement rule, the sleeve is retired without a refit, filter, or
Q02 requeue. The full reconciliation is recorded in
`docs/ops/evidence/2026-07-31_qm5_20183_q02_terminal_retirement.md`.
