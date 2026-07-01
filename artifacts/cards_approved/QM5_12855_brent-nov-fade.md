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
expected_trade_frequency: "November-only D1 Brent month-of-year weakness sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_approval_reasoning: "R1 PASS existing research-paper source packet covering WTI and Brent crude-oil seasonality; R2 PASS deterministic November D1 short/time-flat rule with ATR stop; R3 PASS XBRUSD.DWX locally routed by prior Brent builds with Q02 validating current history; R4 PASS no ML/grid/martingale/external data."
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
---

# Brent November Calendar Fade

Approved copy of `strategy-seeds/cards/approved/QM5_12855_brent-nov-fade_card.md`.

This card mechanizes a deterministic Brent D1 November weakness sleeve from the
Khan, Saha, and Ekundayo WTI/Brent crude-oil seasonality source. It sells
`XBRUSD.DWX` on broker-calendar November D1 bars, exits on the next D1 bar or a
one-day stale-position guard, uses a per-trade ATR hard stop, and runs Q02 with
`RISK_FIXED=1000`.

It is not a duplicate of `QM5_12854_brent-dec-fade` because it isolates the
other weak-month leg. It is also distinct from WTI November, Brent May, Brent
weekday, Brent TSMOM, Brent/WTI spread, XTI/XNG, XNG, XAU/XAG, index, and
commodity RSI sleeves. It does not add XAU, SP500, NDX, or XNG exposure and
uses no external runtime feed, ML, grid, martingale, portfolio gate file, live
manifest, or AutoTrading control.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `D:\QM\reports\framework\21\build_check_20260701_132306.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `50b7b820-f9b5-421e-b614-3d7955dc877f` |
