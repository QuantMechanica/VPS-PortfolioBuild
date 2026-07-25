# QM5_20160 XNG Friday Trend — Build And Q02 Evidence

**Date:** 2026-07-25
**Branch:** `agents/board-advisor`
**EA:** `QM5_20160_xng-fri-trend`

## Edge and governance

The new structural energy edge sells only a genuine Friday `XNGUSD.DWX` D1
session immediately following a Thursday bar, and only when the completed
252-D1 log return is negative. Borowski (2016) supplies the negative Friday
natural-gas sample direction; Moskowitz, Ooi, and Pedersen (2012) supply the
own-return-sign state. The conjunction is a transparent QM falsification
hypothesis.

The mechanic is distinct from `QM5_12567_cum-rsi2-commodity` (two-day
oscillator pullback), `QM5_20094_xng-fri-short` (unconditional weekday
short), and the Monday/Tuesday/Wednesday trend-conditioned siblings. No
profitability, certification, or portfolio-decorrelation claim is made before
pipeline evidence.

## Build evidence

- EA ID: `20160`
- Magic: `201600000`, slot 0, `XNGUSD.DWX`
- Card schema/ML lint: PASS
- G0 card lint: PASS
- Build prerequisite guard: PASS
- SPEC validation: PASS
- Strict compile: PASS, 0 errors, 0 warnings
- Compile log:
  `framework/build/compile/20260725_190216/QM5_20160_xng-fri-trend.compile.log`
- EX5 SHA256:
  `489B1A28C31DA8021CBE690E4CA8A69F7936CF2E0A4A876281B127B2FD55BA64`
- Targeted build check: PASS, 0 failures, 0 warnings
- Build report:
  `D:/QM/reports/framework/21/build_check_20260725_190451.json`
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`

The repository-wide registry validator still reports pre-existing legacy
registry defects. Its scoped output contains no `20160` failure. The atomic
EA-ID reservation, magic resolver regeneration, build guard, strict compile,
and targeted build check all pass for this EA.

No manual smoke test or backtest was started.

## Paced Q02 handoff

Exactly one work item was enqueued:

- Work item: `1a253cfa-4b9a-4ef3-a707-6589dd0f4972`
- Phase: `Q02`
- Symbol/timeframe: `XNGUSD.DWX` / `D1`
- State at handoff: `pending`

The T1–T10 slot inspection showed no active factory backtest terminals, so the
mission CPU-ceiling stop was not triggered. No portfolio gate, T_Live
manifest, live setfile, terminal, AutoTrading state, or live deployment
artifact was changed.
