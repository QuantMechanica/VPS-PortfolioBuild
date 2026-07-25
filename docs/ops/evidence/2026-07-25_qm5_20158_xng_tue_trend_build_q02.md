# QM5_20158 XNG Tuesday Trend — Build And Q02 Evidence

**Date:** 2026-07-25
**Branch:** `agents/board-advisor`
**EA:** `QM5_20158_xng-tue-trend`

## Edge and governance

The new edge buys only a genuine Tuesday `XNGUSD.DWX` D1 session when the
instrument's completed 252-D1 log return is positive. It joins the
peer-reviewed positive Tuesday natural-gas sample return reported by Borowski
(2016) with the peer-reviewed own-return sign state of Moskowitz, Ooi, and
Pedersen (2012).

Deterministic pre-allocation dedup returned `CLEAN` across 4,215 registry rows
and 376 cards for strategy
`BOROWSKI-MOP-XNG-TUETREND-2026_S01`. The mechanic differs from
`QM5_12567_cum-rsi2-commodity` because it uses a weekly calendar boundary and
252-D1 directional state, not a two-day oscillator reversal. It also differs
from unconditional `QM5_12818_xng-tue-prem`.

## Build evidence

- EA ID: `20158`
- Magic: `201580000`, slot 0, `XNGUSD.DWX`
- Card schema and ML lint: PASS
- Strict compile: PASS, 0 errors, 0 warnings
- Compile log:
  `framework/build/compile/20260725_171854/QM5_20158_xng-tue-trend.compile.log`
- Targeted build check: PASS, 0 failures, 0 warnings
- Build report:
  `D:/QM/reports/framework/21/build_check_20260725_172040.json`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

No manual smoke test or backtest was started.

## Paced Q02 handoff

The capacity scan found zero running factory testers. T_Live and FTMO were
identified as non-pipeline processes and untouched.

Build task `b04b05cc-74b6-4018-90c8-ae31a65b56a9` completed and auto-enqueued
exactly one work item:

- Work item: `c9957a9c-1c39-4d3a-b29a-c655f7dacbac`
- Phase: `Q02`
- Symbol/timeframe: `XNGUSD.DWX` / `D1`
- State: `pending`

No portfolio gate, T_Live manifest, live setfile, terminal, AutoTrading state,
or live deployment artifact was changed.
