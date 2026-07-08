---
ea_id: QM5_13056
slug: xbr-1w-rev-vol
status: APPROVED
source_id: ZHAO-ST-MOMREV-2026
---

# XBR One-Week High-Volatility Reversal

Build copy of `strategy-seeds/cards/xbr-1w-rev-vol_card.md`.

The EA trades only `XBRUSD.DWX` D1. It fades the sign of a prior five-day
closed-bar return when realized volatility ranks above the configured
percentile floor, then exits by ATR stop, time, neutral-return condition, or
framework Friday close.

Runtime is restricted to Darwinex MT5 D1 OHLC, spread, ATR, broker calendar,
and V5 framework state. No futures curve, COT, EIA, ETF roll, CSV, API,
analyst forecast, ML, grid, martingale, live manifest, `T_Live`, or portfolio
gate is used.

Build validation: `artifacts/qm5_13056_build_result.json`.
Q02 enqueue evidence: `artifacts/qm5_13056_q02_enqueue_20260708.json`.
