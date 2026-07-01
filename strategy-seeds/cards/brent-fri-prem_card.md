---
ea_id: QM5_12865
slug: brent-fri-prem
type: strategy
strategy_id: QUAY-WTI-DOW-2019_BRENT_S03
source_id: QUAY-WTI-DOW-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
sources:
  - "[[sources/QUAY-WTI-DOW-2019]]"
concepts:
  - "[[concepts/crude-oil-day-of-week-seasonality]]"
  - "[[concepts/brent-calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, day-of-week, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly D1 Brent Friday-calendar premium sleeve; estimate 40-52 entries/year before broker holidays, Friday close, XBR history availability, and framework filters."
expected_trades_per_year_per_symbol: 46
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
---

# Brent Friday Calendar Premium

Canonical approved card:

`strategy-seeds/cards/approved/QM5_12865_brent-fri-prem_card.md`

This card isolates a low-frequency Brent Friday day-of-week premium from the
peer-reviewed Quayyum et al. crude-oil seasonality source. It buys
`XBRUSD.DWX` only on broker-calendar Friday D1 bars, uses an ATR hard stop, and
flattens through framework Friday close, the first subsequent D1 bar, or a
one-calendar-day stale guard.

Runtime uses Darwinex MT5 OHLC and broker calendar only. No external feed, ML,
grid, martingale, live manifest, `T_Live`, portfolio gate, or AutoTrading change
is part of this card.
