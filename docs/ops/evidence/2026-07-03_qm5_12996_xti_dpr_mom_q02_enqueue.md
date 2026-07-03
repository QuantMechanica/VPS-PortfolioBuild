# QM5_12996 XTI DPR Momentum - Q02 Enqueue Evidence

Date: 2026-07-03
Operator: Codex
Branch: `agents/board-advisor`

## Scope

Built one new structural commodity/energy sleeve:

- EA: `QM5_12996_xti-dpr-mom`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Edge: monthly EIA Drilling Productivity Report / shale-production proxy
  window momentum with ATR range/body, Donchian breakout, SMA trend, ATR
  stop/target, and time/trend exits.
- Source: U.S. Energy Information Administration, Drilling Productivity Report
  and DPR FAQ:
  - https://www.eia.gov/petroleum/drilling/
  - https://www.eia.gov/petroleum/drilling/faqs.php

## Non-Duplicate Rationale

No local DPR, shale-production, or tight-oil information-window sleeve existed.
This build is distinct from:

- `QM5_12992_eia-steo-brk`: STEO first-Tuesday release-date breakout, not the
  historical mid-month DPR window.
- `QM5_12988_xti-eia-inventory-momentum`: weekly WPSR reaction momentum, not a
  monthly shale-production proxy.
- OPEC, IEA, MOMR, Cushing, refinery, hurricane, rig-count, roll, expiry,
  WTI month/weekday/weekend, 52-week anchor, 6-month reversal, carry, XTI/XNG,
  oil/gold, oil/silver, XAU/XAG, XNG, index, and
  `QM5_12567_cum-rsi2-commodity`: no event-feed parser, no ratio basket, no
  RSI, no oscillator, no ML, no grid, no martingale.

## Build Validation

- Card schema lint: PASS
- SPEC validation: PASS
- Symbol scope: `SINGLE_SYMBOL_OK`
- Magic registry: `12996 / slot 0 / XTIUSD.DWX / 129960000 / active`
- Compile: PASS, 0 errors, 0 warnings
- Compile log: `C:\QM\repo\framework\build\compile\20260703_122725\QM5_12996_xti-dpr-mom.compile.log`
- Strict build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings
- Build check report: `D:\QM\reports\framework\21\build_check_20260703_122738.json`
- Build result artifact: `artifacts/qm5_12996_build_result.json`

## Q02 Queue

- Work item: `54ca3518-644b-45b3-ab97-00b8ac865cd2`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: Q02
- Status after enqueue: pending
- Setfile: `framework/EAs/QM5_12996_xti-dpr-mom/sets/QM5_12996_xti-dpr-mom_XTIUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Safety

No manual MT5 backtest was launched from this session. No `T_Live`,
AutoTrading, portfolio gate, or live manifest file was touched.
