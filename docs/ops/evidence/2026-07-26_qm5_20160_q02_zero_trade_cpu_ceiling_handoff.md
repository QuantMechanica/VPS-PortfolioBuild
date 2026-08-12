# QM5_20160 Q02 zero-trade recovery handoff

**Date:** 2026-07-26  
**Branch:** `agents/board-advisor`  
**EA:** `QM5_20160_xng-fri-trend`  
**Disposition:** `DRAFT_DEFECT_REQUIRES_INSTRUMENTED_RECOVERY`; no re-enqueue

## Mission fit

`QM5_20160` is the governed new energy-sleeve candidate selected for the
OWNER commodity/energy mission. It sells only a genuine Friday
`XNGUSD.DWX` D1 session when the completed 252-D1 return is negative. The
weekday/trend interaction is structurally different from the certified
`QM5_12567_cum-rsi2-commodity` two-day oscillator pullback.

The source-backed card, deterministic registry allocation, EA, fixed-risk
setfile, strict compile, and initial Q02 enqueue were committed previously.
This review does not claim certification, profitability, or decorrelation.

## Bound failed run

| Field | Evidence |
|---|---|
| Work item | `1a253cfa-4b9a-4ef3-a707-6589dd0f4972` |
| Phase/verdict | `Q02` / `DRAFT_DEFECT` |
| Window | `2018-07-02` through `2022-12-31` |
| Symbol/timeframe/model | `XNGUSD.DWX` / `D1` / real ticks (Model 4) |
| Report | `D:/QM/reports/work_items/1a253cfa-4b9a-4ef3-a707-6589dd0f4972/QM5_20160/20260725_195517/raw/run_01/report.htm` |
| Summary | `D:/QM/reports/work_items/1a253cfa-4b9a-4ef3-a707-6589dd0f4972/QM5_20160/20260725_195517/summary.json` |
| Trades | `0` |
| Source/deployed EX5 | identical SHA256 `489b1a28c31da8021cbe690e4ca8a69f7936cf2e0a4a876281b127b2fd55ba64` |
| Source/deployed set | identical SHA256 `08ee920d91593a64b013ba7f6d19e3ead5098b1e8b7d4e88d078d4f983497d10` |
| Harness | valid non-empty report, stable identities, no `ONINIT_FAILED`, real-tick marker present |

The harness and initialization layers are valid. The captured structured log
contains 1,392 events, including 222 `FRIDAY_CLOSE` events, but no entry
attempt, reject-reason, signal-fire, or order event. Therefore the first failed
layer is narrowed to the entry hook, but the current binary lacks enough
bounded decision diagnostics to distinguish calendar/grace, persisted attempt,
history, trend, spread, ATR, quote, or stop rejection. Zero trades are not an
economic verdict.

## Required minimal recovery

1. Add one rate-limited Friday decision marker and one explicit reject reason
   per attempted Friday. Do not alter the approved weekday, momentum horizon,
   direction, grace period, stop, hold, spread cap, or risk mode.
2. Strict-compile the same EA lineage.
3. On a confirmed-free `T1`-`T5` terminal, rerun the same evidence-bound
   2018-07-02 through 2022-12-31 case and require at least one trade only as a
   trade-capability proof.
4. Re-enqueue Q02 only after the first failed gate is proven and any repair is
   mapped directly to the approved card.

## CPU ceiling stop

At `2026-07-26T11:33:06Z`, factory slot inspection showed seven active
factory backtests on `T1,T2,T3,T6,T8,T9,T10`. This meets the mission's
backtest CPU ceiling. No manual tester, terminal, re-enqueue, or factory
recovery action was started.

No `T_Live` file, process, AutoTrading state, live setfile, deploy manifest,
portfolio gate, or T_Live manifest was touched.
