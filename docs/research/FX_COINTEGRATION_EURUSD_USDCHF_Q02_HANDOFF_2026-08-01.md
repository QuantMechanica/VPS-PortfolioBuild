# QM5_20191 EURUSD/USDCHF Cointegration Q02 Handoff

Date: 2026-08-01

Branch: `agents/board-advisor`

State: `Q02_PENDING` (logical-basket work item
`5cd924e8-af79-4f0e-9699-846dcf72e5b5`)

## Selection

The two proven anchor baskets are not blocked at Q02: `QM5_12532` passed Q02
before failing Q05, and `QM5_12533` passed Q02 before failing Q04. The next
non-duplicate action was therefore selected from the same fixed 66-pair scan.

`EURUSD.DWX` / `USDCHF.DWX` ranks tenth by OOS net Sharpe in the sign-aware
rerun and is the first ranked relationship after the terminal-retired
`QM5_20183` continuation without a dedicated D1 two-leg manifest:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDCHF | -0.310802 | 0.751252 | 3.970936% | 17 | -0.585986704 | 347.361 D1 bars |

The negative DEV result and sub-0.8 OOS Sharpe are preserved as adverse
evidence. The card authorizes one low-frequency frontier test and requires
retirement on terminal economic Q02 failure or sub-floor cadence; it forbids
a filter, refit, or parameter rescue.

The older `QM5_1156` M30 umbrella enumerates this relationship as one of 15
adaptive slots, but it has no dedicated EURUSD/USDCHF D1 logical manifest.
That umbrella overlap is not a duplicate of this fixed-beta, fixed-pair D1
sleeve, matching the precedent used for `QM5_20183`.

Source lineage:

- `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
- `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`
- `framework/scripts/mt5_diagnostics/analyze_cross_asset_v3.py
  --include-negative-hedges`

## Build

- EA ID / label: `20191` / `QM5_20191_eurusd-chf-coint`
- Build commit: `c0fa40db8`
- Logical symbol: `QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1`
- Host / companion: `EURUSD.DWX` D1 / `USDCHF.DWX`
- Magic slots: `201910000`, `201910001`
- Fixed beta: `-0.585986704`; negative-beta long spread buys both legs and
  short spread sells both legs
- Entry / exit: `abs(z) > 2.0` / `abs(z) < 0.5`, using a strictly prior
  60-bar closed-D1 calibration window
- Hard stops: `ATR(20, D1) * 2.0` on both legs
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Basket manifest: USD tester currency, USD 100,000 deposit
- Live artifacts: none

Validation:

- Strategy Card schema lint: PASS
- G0 structural lint: PASS
- Build authorization guard: PASS
- Strict V5 build check: PASS, zero failures and zero warnings
- Compile: PASS, zero errors and zero warnings
- Symbol-scope validator: `BASKET_OK`, zero violations
- Basket manifest regression suite: 23 PASS
- Build report:
  `D:\QM\reports\framework\21\build_check_20260801_025812.json`
- Compile summary:
  `D:\QM\reports\compile\20260801_025812\summary.csv`

The repository-wide registry validator remains red on pre-existing legacy
inventory defects. The targeted registry/build guard, collision check, new EA
row, two magic rows, and generated resolver entries are internally consistent.

## Q02 Enqueue

The final path-aware precheck at `2026-08-01T03:07:37Z` found three running
factory terminals (`T2`, `T4`, and `T8`) against the seven-terminal ceiling.
The separate T_Live process was excluded, and `FACTORY_OFF.flag` was absent.
The governed critical section rechecked the ceiling and would have aborted at
seven or more terminals.

The targeted sweep created exactly one row at
`2026-08-01T03:09:21Z`:

- Work item: `5cd924e8-af79-4f0e-9699-846dcf72e5b5`
- Phase / kind: `Q02` / `backtest`
- Symbol / timeframe:
  `QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1` / D1
- Setfile:
  `framework/EAs/QM5_20191_eurusd-chf-coint/sets/QM5_20191_eurusd-chf-coint_QM5_20191_EURUSD_USDCHF_COINTEGRATION_D1_D1_backtest.set`
- Immediate state: `pending`, attempt 0, unclaimed, no evidence
- Payload: host `EURUSD.DWX`, two declared basket symbols, USD tester
  currency, USD 100,000 deposit, 450-minute timeout, priority track

The physical-host setfile was explicitly skipped with reason
`basket_manifest_logical_setfile_preferred`. No tester was manually launched
and no Q02 verdict is claimed.

## Safety

- No portfolio admission, KPI, or Q08 contribution file changed.
- No T_Live manifest, terminal, AutoTrading state, or live setfile changed.
- No manual backtest, dispatch, or terminal launch was performed.
