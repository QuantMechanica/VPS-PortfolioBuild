---
ea_id: QM5_12856
slug: brent-mon-fade
type: strategy
strategy_id: QUAY-WTI-DOW-2019_BRENT_S02
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
---

# Brent Monday Calendar Fade

Build-time copy of `strategy-seeds/cards/approved/QM5_12856_brent-mon-fade_card.md`.

The EA sells `XBRUSD.DWX` only on broker-calendar Monday D1 bars, uses a fixed
ATR hard stop, and exits on the first subsequent D1 bar, stale guard, or
framework Friday close. Runtime uses Darwinex MT5 OHLC and broker calendar
only.
