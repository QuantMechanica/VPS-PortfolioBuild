---
ea_id: QM5_12777
slug: wti-dec-fade
type: strategy
source_id: QUAY-WTI-DEC-2019
source_citation: "Quayyum, H. A., Khan, M. A. M. and Ali, S. M. Seasonality in crude oil returns. Soft Computing 24, 7857-7873 (2020). DOI https://doi.org/10.1007/s00500-019-04329-0"
sources:
  - "[[sources/QUAY-WTI-DEC-2019]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/december-calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12777_XTI_DEC_FADE_D1
period: D1
expected_trade_frequency: "December-only D1 WTI month-of-year negative-return sleeve; estimate 18-22 trades/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-06-29
expected_pf: 1.08
expected_dd_pct: 16.0
g0_approval_reasoning: "R1 PASS peer-reviewed crude-oil seasonality source; R2 PASS deterministic December D1 short/next-bar flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
---

# WTI December Calendar Fade

Canonical approved card:
`strategy-seeds/cards/approved/QM5_12777_wti-dec-fade_card.md`.

Summary: D1 `XTIUSD.DWX` December month-of-year fade from the peer-reviewed
crude-oil seasonality source. It sells only broker-calendar December D1 bars,
uses a fixed ATR hard stop, and exits on the next D1 bar, month end, or
max-hold stale guard. Runtime uses Darwinex OHLC, broker calendar, spread, and
ATR only.

Runtime status: `QM5_12777_wti-dec-fade` compiled and passed framework
`build_check` on 2026-06-29, then was enqueued to Q02 as work item
`171bf5f6-c737-4a88-bdbb-0e1d9ef14d61`.
