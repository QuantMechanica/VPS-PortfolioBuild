# QM5_12980 Brent 6M Reversal - Q02 Enqueue Evidence

Date: 2026-07-03
Operator: Codex
Branch: `agents/board-advisor`

## Scope

Built one new structural commodity/energy sleeve:

- EA: `QM5_12980_brent-6m-rev`
- Symbol/timeframe: `XBRUSD.DWX` D1
- Edge: monthly 120-D1 Brent overextension fade with SMA/ATR stretch confirmation
- Source: Bianchi, R. J., Drew, M. E. and Fan, J. H. (2016),
  "Commodities momentum: A behavioural perspective", Journal of Banking and
  Finance, DOI https://doi.org/10.1016/j.jbankfin.2016.06.010, with
  Yang/Goncu/Pantelous commodity reversal lineage as supplement.

## Non-Duplicate Rationale

This build is Brent crude exposure, not the existing XAU/SP500/NDX/XNG book. It
is distinct from:

- `QM5_12979_wti-6m-reversal`: WTI benchmark, not Brent.
- `QM5_12859_brent-52w-anchor` and `QM5_12849_brent-tsmom12m`: continuation
  logic, not contrarian 120-D1 overextension fade.
- Existing Brent weekday/month cards: no fixed calendar anomaly.
- WTI/Brent spread, XTI/XNG, XNG, XAU/XAG, gas-metal, index, and
  `QM5_12567_cum-rsi2-commodity`: no spread basket, no XNG event, no metal
  ratio, no RSI, no oscillator, no ML, no grid, no martingale.

## Build Validation

- Card schema lint: PASS
- SPEC validation: PASS
- Symbol scope: `SINGLE_SYMBOL_OK`
- Build guardrails: PASS
- Compile: COMPILED, 0 errors, 0 warnings
- Strict build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings
- Build check report: `D:\QM\reports\framework\21\build_check_20260703_015538.json`
- Build result artifact: `artifacts/qm5_12980_build_result.json`

## Q02 Queue

- Work item: `08c6889f-3b71-4bd2-b204-7f6ad99330c5`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: Q02
- Status after enqueue: pending
- Setfile: `framework/EAs/QM5_12980_brent-6m-rev/sets/QM5_12980_brent-6m-rev_XBRUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Safety

No manual MT5 backtest was launched from this session. No `T_Live`, AutoTrading,
portfolio gate, or live manifest file was touched.
