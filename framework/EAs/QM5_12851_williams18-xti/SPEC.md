# QM5_12851_williams18-xti - Strategy Spec

**EA ID:** `12851`  
**Slug:** `williams18-xti`  
**Source:** `SRC03` / `SRC03_S12_XTI_20260701`  
**Symbol:** `XTIUSD.DWX`  
**Timeframe:** D1

## Summary

Single-symbol WTI continuation EA based on Williams' 18-bar two-bar moving
average entry. On each new D1 bar, the EA checks the prior two completed bars:
both lows above the 18-day close SMA trigger a buy-stop through the two-bar
high, while both highs below the SMA trigger a sell-stop through the two-bar
low. Inside days invalidate the two-bar setup.

## Non-Duplicate Boundary

This is not the Williams prior-range volatility breakout (`QM5_12842`), because
entry is based on two closed bars relative to an 18-day SMA rather than an
open-plus-prior-range breakout. It is not XTI/XNG ratio, XNG RSI, WTI/Brent
spread, calendar seasonality, inventory, roll, or metal/index exposure.

## Risk And Execution

- Backtest risk mode: `RISK_FIXED=1000`.
- Slot 0: `XTIUSD.DWX`, magic `128510000`.
- Stop entry: two-bar high/low plus/minus buffer.
- Hard stop: `strategy_atr_sl_mult * ATR(strategy_atr_period)`.
- Optional fixed-R take-profit.
- Pending stop expires after `strategy_order_expiry_bars` D1 bars.
- Open positions close after `strategy_max_hold_days`.
- No grid, martingale, pyramiding, partial close, external feed, or ML.

## Q02 Dispatch

Use the single-symbol setfile:

`sets/QM5_12851_williams18-xti_XTIUSD.DWX_D1_backtest.set`

## Pipeline

| version | date | status |
|---|---|---|
| v1 | 2026-07-01 | built for Q02 enqueue |
