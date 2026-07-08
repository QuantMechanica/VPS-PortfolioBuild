---
ea_id: QM5_13054
slug: brent-tom-mom
status: APPROVED
source_id: VANHEMERT-MOMTOM-2014
---

# Brent Turn-Of-Month Momentum

Build copy of `strategy-seeds/cards/brent-tom-mom_card.md`.

The EA trades only `XBRUSD.DWX` D1. Inside the broker-calendar turn-of-month
window, it follows a fixed completed-D1 momentum return sign, then exits on
window end, max-hold expiry, Friday close, or ATR stop/target.

Runtime is restricted to Darwinex MT5 D1 OHLC, spread, ATR, broker calendar,
and V5 framework state. No CTA holdings, futures curves, EIA/CFTC/OPEC data,
CSV, API, analyst forecast, ML, grid, martingale, live manifest, `T_Live`, or
portfolio gate is used.
