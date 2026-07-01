---
ea_id: QM5_12854
slug: brent-dec-fade
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_BRENT_S03
source_id: KHAN-WTI-BRENT-SEASON-2023
source_citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent. Research Square posted content. DOI 10.21203/rs.3.rs-2569101/v1."
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
period: D1
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
last_updated: 2026-07-01
expected_trade_frequency: "December-only D1 Brent month-of-year weakness sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_approval_reasoning: "R1 PASS single research-paper source URL; R2 PASS deterministic December D1 short/time-flat rule with ATR stop; R3 PASS XBRUSD.DWX locally routed by prior Brent builds with Q02 validating current history; R4 PASS no ML/grid/martingale/external data."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
---

# Brent December Calendar Fade

Approved copy of `strategy-seeds/cards/approved/QM5_12854_brent-dec-fade_card.md`.

This card mechanizes a deterministic Brent D1 December weakness sleeve from the
Khan, Saha, and Ekundayo WTI/Brent crude-oil seasonality source. It sells
`XBRUSD.DWX` on broker-calendar December D1 bars, exits on the next D1 bar or a
one-day stale-position guard, uses a per-trade ATR hard stop, and runs Q02 with
`RISK_FIXED=1000`.

It is not a duplicate of `QM5_12777_wti-dec-fade` because it targets the Brent
benchmark, not WTI. It is also distinct from the Brent May, Brent weekday,
Brent TSMOM, Brent/WTI spread, XTI/XNG, XNG, XAU/XAG, index, and commodity RSI
sleeves. It does not add XAU, SP500, NDX, or XNG exposure and uses no external
runtime feed, ML, grid, martingale, portfolio gate file, live manifest, or
AutoTrading control.
