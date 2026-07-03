# QM5_12998 XTI SPR Relief - Q02 Enqueue Evidence

Date: 2026-07-03
Operator: Codex
Branch: `agents/board-advisor`

## Scope

Built one new structural commodity/energy sleeve:

- EA: `QM5_12998_xti-spr-relief`
- Symbol/timeframe: `XTIUSD.DWX` D1
- Edge: weekly EIA SPR stock disclosure-window failed 126-D1 WTI extreme
  reversal, with ATR range/probe/rejection, SMA stretch, ATR stop, slow-SMA
  mean exit, time exit, and standard V5 guards.
- Sources:
  - https://www.eia.gov/petroleum/supply/weekly/
  - https://www.eia.gov/dnav/pet/hist/LeafHandler.ashx?f=W&n=PET&s=WCSSTUS1
  - https://www.energy.gov/hgeo/opr/spr-quick-facts

## Non-Duplicate Rationale

This build is distinct from `QM5_12755_wti-spr-refill-bounce`: that older EA is
long-only around a fixed DOE SPR refill price zone. `QM5_12998` has no fixed
USD policy-zone and trades symmetric failed 126-D1 highs/lows around the weekly
SPR/WPSR disclosure proxy.

It is also distinct from WPSR continuation/fade/inside-bar/pre-event, DPR,
STEO, OPEC, IEA, Cushing, refinery, hurricane, rig-count, roll, seasonality,
XTI/XNG, oil-metal, XNG, XAU/XAG, index, and `QM5_12567` commodity RSI logic.

## Build Validation

- Card schema lint: PASS
- SPEC validation: PASS
- Symbol scope: `SINGLE_SYMBOL_OK`
- Build guardrails: PASS
- Magic registry: `12998 / slot 0 / XTIUSD.DWX / 129980000 / active`
- Compile: PASS, 0 errors, 0 warnings
- Compile log: `C:\QM\repo\framework\build\compile\20260703_141013\QM5_12998_xti-spr-relief.compile.log`
- Strict build check: PASS, 0 failures, 16 shared-framework DWX advisory warnings
- Build check report: `D:\QM\reports\framework\21\build_check_20260703_141013.json`
- Build result artifact: `artifacts/qm5_12998_build_result.json`

## Q02 Queue

- Work item: `317fd95c-c4ba-4b8e-baef-450604c4c0aa`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Phase: Q02
- Status after enqueue: pending
- Setfile: `framework/EAs/QM5_12998_xti-spr-relief/sets/QM5_12998_xti-spr-relief_XTIUSD.DWX_D1_backtest.set`
- Risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`

## Safety

No manual MT5 backtest was launched from this session. No `T_Live`,
AutoTrading, portfolio gate, or live manifest file was touched.
