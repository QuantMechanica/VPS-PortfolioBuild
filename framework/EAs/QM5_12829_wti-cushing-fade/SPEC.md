---
ea_id: QM5_12829
slug: wti-cushing-fade
status: built
source_card: strategy-seeds/cards/approved/QM5_12829_wti-cushing-fade_card.md
---

# QM5_12829 WTI Cushing Failed-Spike Fade

Single-symbol V5 EA for `XTIUSD.DWX` D1.

## Build Contract

- Runtime data: Darwinex MT5 OHLC, spread, broker clock, framework news state.
- No runtime EIA feed, futures curve, CSV, API, ML, grid, martingale, or live
  deploy touch.
- Backtest setfile uses `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## Module Mapping

- No-trade: D1/XTI host guard, slot-0 guard, parameter sanity, spread cap.
- Entry: weekly failed upside channel pierce with weak close in an uptrend.
- Management: close below fast SMA or after max hold.
- Close: ATR hard stop on entry and framework Friday close.

