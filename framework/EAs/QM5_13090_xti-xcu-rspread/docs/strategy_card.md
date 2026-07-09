---
copy_of: strategy-seeds/cards/xti-xcu-rspread_card.md
ea_id: QM5_13090
slug: xti-xcu-rspread
type: strategy
strategy_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
source_id: EIA-CME-USGS-XTI-XCU-RSPREAD-2026
target_symbols: [XTIUSD.DWX, XCUUSD.DWX]
basket_symbols: [XTIUSD.DWX, XCUUSD.DWX]
logical_symbol: QM5_13090_XTI_XCU_RSPREAD_D1
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-09
---

# QM5_13090 XTI/XCU Return-Spread Reversion

See `strategy-seeds/cards/xti-xcu-rspread_card.md` for the approved card body.

This EA implements the approved D1 `XTIUSD.DWX` / `XCUUSD.DWX` return-spread
reversion basket. It runs from the `XTIUSD.DWX` D1 host chart, computes
fixed-window WTI-minus-copper log-return spread z-scores, opens paired legs
against z-score extremes, and closes on z-score normalization, max hold, Friday
close, orphan repair, or per-leg ATR hard stops.
