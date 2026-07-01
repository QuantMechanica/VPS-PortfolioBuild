# QM5_12850_xti-xng-vcb - Strategy Spec

**EA ID:** `12850`  
**Slug:** `xti-xng-vcb`  
**Source:** `BOLLINGER-BB-SQUEEZE-2001`  
**Logical symbol:** `QM5_12850_XTI_XNG_VCB_D1`  
**Host:** `XTIUSD.DWX` D1

## Summary

Two-leg energy basket on `XTIUSD.DWX` and `XNGUSD.DWX`. On each new D1 host bar
the EA computes the completed-bar log ratio:

`ln(XTIUSD) - beta * ln(XNGUSD)`

It computes Bollinger middle/stddev on prior ratio observations, ranks the
current BandWidth against recent BandWidth history, and trades only when a low
BandWidth state resolves into a close-confirmed ratio breakout.

## Non-Duplicate Boundary

This is not `QM5_12608_eia-oilgas-breakout`, which uses a raw channel breakout
on the XTI/XNG log ratio. This EA requires ratio BandWidth compression before
entry and exits on Bollinger middle-band failure. It is also not XTI/XNG z-score
reversion, return-spread reversion, monthly relative momentum, fixed seasonal
switching, WTI-only volatility breakout, XNG RSI, or any metal/index sleeve.

## Risk And Execution

- Backtest risk mode: `RISK_FIXED=1000`.
- Slot 0: `XTIUSD.DWX`, magic `128500000`.
- Slot 1: `XNGUSD.DWX`, magic `128500001`.
- Risk is split across the two legs by fixed risk weights.
- Each leg receives an ATR hard stop.
- Package exits on middle-band failure, max-hold, Friday close, or broken-leg
  repair.
- No grid, martingale, pyramiding, partial close, external feed, or ML.

## Q02 Dispatch

Use the logical basket setfile:

`sets/QM5_12850_xti-xng-vcb_QM5_12850_XTI_XNG_VCB_D1_D1_backtest.set`

Q02 must evaluate the logical basket rather than standalone legs.

## Pipeline

| version | date | status |
|---|---|---|
| v1 | 2026-07-01 | built for Q02 enqueue |
