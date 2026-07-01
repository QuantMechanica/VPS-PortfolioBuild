# QM5_12858_rigcount-fri-mom - Strategy Spec

**EA ID:** `12858`  
**Slug:** `rigcount-fri-mom`  
**Source:** `BAKERHUGHES-RIGCOUNT-2026`  
**Host:** `XTIUSD.DWX` D1

## Summary

Single-symbol WTI sleeve. On the first D1 bar of a new broker week, the EA
checks the prior completed D1 bar, which is the final workday of the prior week
and the market-reaction proxy for the weekly Baker Hughes North America Rig
Count. If that bar has a large close-to-close move, the close is near the bar
extreme, and spread/risk checks pass, the EA enters in the same direction.

## Non-Duplicate Boundary

This is not a WTI static weekday/month anomaly, weekend-gap bounce/fade, WPSR,
Cushing, refinery, hurricane, OPEC, SPR, expiry, ETF-roll, broad seasonality,
XTI/XNG ratio, metals-ratio, XNG, or RSI commodity sleeve. It requires a large
completed final-workday displacement and uses only short new-week continuation.

## Risk And Execution

- Backtest risk mode: `RISK_FIXED=1000`.
- Slot 0: `XTIUSD.DWX`, magic `128580000`.
- ATR hard stop on entry.
- Time stop after `strategy_max_hold_days`.
- Adverse completed-close exit if price reverses against entry by an ATR
  fraction.
- No grid, martingale, pyramiding, partial close, external feed, or ML.

## Q02 Dispatch

Use the backtest setfile:

`sets/QM5_12858_rigcount-fri-mom_XTIUSD.DWX_D1_backtest.set`

## Pipeline

| version | date | status |
|---|---|---|
| v1 | 2026-07-01 | built for Q02 enqueue |
