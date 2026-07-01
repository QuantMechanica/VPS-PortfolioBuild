---
ea_id: QM5_12855
slug: brent-nov-fade
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_BRENT_S04
source_id: KHAN-WTI-BRENT-SEASON-2023
source_citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent. Research Square posted content. DOI 10.21203/rs.3.rs-2569101/v1."
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
---

# Brent November Calendar Fade

Build-time copy of `strategy-seeds/cards/approved/QM5_12855_brent-nov-fade_card.md`.

The EA sells `XBRUSD.DWX` only on broker-calendar November D1 bars, uses a fixed
ATR hard stop, and exits on the first subsequent D1 bar, month exit, stale guard,
or framework Friday close. Runtime uses Darwinex MT5 OHLC and broker calendar
only.
