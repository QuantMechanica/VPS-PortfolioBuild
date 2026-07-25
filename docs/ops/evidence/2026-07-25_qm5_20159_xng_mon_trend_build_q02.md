# QM5_20159 XNG Monday Trend — Build And Q02 Evidence

**Date:** 2026-07-25  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_20159_xng-mon-trend`

## Edge and governance

The new structural energy edge buys only a genuine Monday `XNGUSD.DWX` D1
session immediately following a Friday bar, and only when the completed
252-D1 log return is positive. Borowski (2016) supplies the positive Monday
natural-gas sample direction; Moskowitz, Ooi, and Pedersen (2012) supply the
own-return-sign state. The conjunction is a transparent QM hypothesis.

The mechanic is distinct from `QM5_12567_cum-rsi2-commodity` (two-day
oscillator pullback), `QM5_12806_xng-rev-weekend` (fixed weekday directions),
and the Tuesday/Wednesday trend interactions. No profitability or portfolio
decorrelation is claimed before pipeline evidence.

## Build evidence

- EA ID: `20159`
- Magic: `201590000`, slot 0, `XNGUSD.DWX`
- Card schema and ML lint: PASS
- SPEC validation: PASS
- Strict compile: PASS, 0 errors, 0 warnings
- Compile log:
  `framework/build/compile/20260725_181819/QM5_20159_xng-mon-trend.compile.log`
- Targeted build check: PASS, 0 failures, 0 warnings
- Build report:
  `D:/QM/reports/framework/21/build_check_20260725_181819.json`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

No manual smoke test or backtest was started.

## Paced Q02 handoff

Farm build task `c72da7f2-bcef-4e6f-825a-59c849800266` completed and
auto-enqueued exactly one work item:

- Work item: `0e3a27ec`
- Phase: `Q02`
- Symbol/timeframe: `XNGUSD.DWX` / `D1`
- State: `pending`

No portfolio gate, T_Live manifest, live setfile, terminal, AutoTrading state,
or live deployment artifact was changed.
