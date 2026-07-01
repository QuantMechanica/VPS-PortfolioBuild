# QM5_12857 XBR/XNG Ratio VCB Q02 Enqueue

Date: 2026-07-01
Branch: `agents/board-advisor`
Owner: Codex

## Edge Built

- EA: `QM5_12857_xbr-xng-vcb`
- Strategy ID: `BOLLINGER-BB-SQUEEZE-2001_XBR_XNG_VCB`
- Logical basket: `QM5_12857_XBR_XNG_VCB_D1`
- Host: `XBRUSD.DWX` D1
- Basket legs: `XBRUSD.DWX`, `XNGUSD.DWX`
- Source lineage: approved `BOLLINGER-BB-SQUEEZE-2001` source packet.
- Runtime data: DWX/MT5 OHLC, spread, ATR, broker calendar, and framework state only.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Non-Duplicate Rationale

This sleeve trades a Brent/natural-gas market-neutral energy ratio:

`ln(XBRUSD) - beta * ln(XNGUSD)`

It requires a low Bollinger BandWidth state on the completed D1 ratio series,
then trades a close-confirmed envelope breakout with a middle-band failure exit.
It is distinct from:

- XTI/XNG z-score reversion, raw channel breakout, return-spread reversion,
  monthly relative momentum, and fixed seasonal switching.
- Single-symbol Brent/WTI trend, calendar, and squeeze sleeves.
- WTI/Brent spread reversion/breakout.
- XNG RSI or outright natural-gas logic.
- XAU/XAG, oil/gold, oil/silver, gas/gold, gas/silver, index, and metal sleeves.

## Validation

- Compile:
  `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12857_xbr-xng-vcb/QM5_12857_xbr-xng-vcb.mq5 -Strict`
  - Result: PASS, 0 errors, 0 warnings.
- Build check:
  `powershell -NoProfile -ExecutionPolicy Bypass -File framework/scripts/build_check.ps1 -EALabel QM5_12857_xbr-xng-vcb -Strict`
  - Result: PASS, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Setfile build hash: `591f37e0d34edfc18970fe8cd4fc0391047fe8b2e85876ff569b8cd762be9773`.
- EX5: `framework/EAs/QM5_12857_xbr-xng-vcb/QM5_12857_xbr-xng-vcb.ex5`.
- Build artifact: `artifacts/qm5_12857_build_result.json`.

## Q02 Queue

- Q02 work item: `189ba50a-caf0-4402-acde-623a4d2d7ff3`
- Queue DB: `D:\QM\strategy_farm\state\farm_state.sqlite`
- Status at enqueue: pending
- Created UTC: `2026-07-01T15:07:54+00:00`
- Queue method: direct `record_build_result.auto_q02` basket-manifest path.

## Safety

No MT5 live trading, AutoTrading toggle, `T_Live`, deploy manifest, portfolio
gate, portfolio admission, or portfolio KPI file was touched. No manual
backtest was launched from this session; the paced Q02 fleet owns the first MT5
run and must validate XBR/XNG synchronized history sufficiency.
