---
ea_id: QM5_13055
slug: xbr-1w-mom-vol
status: APPROVED
source_id: ZHAO-ST-MOMREV-2026
---

# XBR One-Week Low-Volatility Momentum

Build copy of `strategy-seeds/cards/xbr-1w-mom-vol_card.md`.

The EA trades only `XBRUSD.DWX` D1. It follows the sign of a prior five-day
closed-bar return when realized volatility ranks below the configured
percentile cap, then exits by ATR stop, time, opposite-return condition, or
framework Friday close.

Runtime is restricted to Darwinex MT5 D1 OHLC, spread, ATR, broker calendar,
and V5 framework state. No futures curve, COT, EIA, ETF roll, CSV, API,
analyst forecast, ML, grid, martingale, live manifest, `T_Live`, or portfolio
gate is used.
