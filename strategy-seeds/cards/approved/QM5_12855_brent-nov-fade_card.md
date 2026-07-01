---
ea_id: QM5_12855
slug: brent-nov-fade
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_BRENT_S04
source_id: KHAN-WTI-BRENT-SEASON-2023
source_citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent. Research Square posted content. DOI 10.21203/rs.3.rs-2569101/v1."
source_citations:
  - type: posted_research_paper
    citation: "Khan, Z., Saha, T. R. and Ekundayo, T. Understanding the Seasonality in Crude Oil Returns for WTI and Brent."
    location: "https://www.researchsquare.com/article/rs-2569101/v1.pdf"
    quality_tier: B
    role: primary
sources:
  - "[[sources/KHAN-WTI-BRENT-SEASON-2023]]"
concepts:
  - "[[concepts/crude-oil-month-of-year-seasonality]]"
  - "[[concepts/calendar-fade]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XBRUSD.DWX]
primary_target_symbols: [XBRUSD.DWX]
markets: [XBRUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "November-only D1 Brent month-of-year weakness sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS existing research-paper source packet covering WTI and Brent crude-oil seasonality; R2 PASS deterministic November D1 short/time-flat rule with ATR stop; R3 PASS XBRUSD.DWX locally routed by prior Brent builds with Q02 validating current history; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, friday_close, magic_schema, risk_mode_dual]
---

# Brent November Calendar Fade

See `strategy-seeds/cards/brent-nov-fade_card.md` for the canonical approved card.

This approved copy mechanizes the source-backed November weak-month side from
the Khan, Saha, and Ekundayo WTI/Brent crude-oil seasonality packet. It sells
`XBRUSD.DWX` on broker-calendar November D1 bars, exits on the next D1 bar or a
one-day stale-position guard, uses a per-trade ATR hard stop, and runs Q02 with
`RISK_FIXED=1000`.

It is not a duplicate of `QM5_12854_brent-dec-fade` because this card isolates
November instead of December. It is not a duplicate of `QM5_12726_wti-nov-fade`
because it targets Brent, not WTI. It also differs from Brent May, Brent
weekday, Brent TSMOM, Brent/WTI spread, XTI/XNG, XNG, XAU/XAG, index, and
commodity RSI sleeves.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
| Q01 Build Validation | 2026-07-01 | PASS | `D:\QM\reports\framework\21\build_check_20260701_132306.json` |
| Q02 Baseline Screening | 2026-07-01 | QUEUED | `D:\QM\strategy_farm\state\farm_state.sqlite` work item `50b7b820-f9b5-421e-b614-3d7955dc877f` |
