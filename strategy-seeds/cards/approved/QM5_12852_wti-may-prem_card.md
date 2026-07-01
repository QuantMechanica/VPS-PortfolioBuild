---
ea_id: QM5_12852
slug: wti-may-prem
type: strategy
strategy_id: KHAN-WTI-BRENT-SEASON-2023_S01
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
  - "[[concepts/calendar-premium]]"
indicators:
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, month-of-year, atr-hard-stop, time-stop, long-only, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [XTIUSD.DWX]
single_symbol_only: true
period: D1
timeframes: [D1]
expected_trade_frequency: "May-only D1 WTI month-of-year positive-return sleeve; estimate 18-22 entries/year after weekends, broker holidays, and framework filters."
expected_trades_per_year_per_symbol: 20
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS single research-paper source URL; R2 PASS deterministic May D1 long/time-flat rule with ATR stop; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external data."
expected_pf: 1.08
expected_dd_pct: 16.0
risk_class: medium
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
---

# WTI May Calendar Premium

See `strategy-seeds/cards/wti-may-prem_card.md` for the canonical approved card.

## Source

- Source: [[sources/KHAN-WTI-BRENT-SEASON-2023]]
- Primary citation: Khan, Z., Saha, T. R. and Ekundayo, T.,
  "Understanding the Seasonality in Crude Oil Returns for WTI and Brent",
  Research Square posted content, DOI 10.21203/rs.3.rs-2569101/v1,
  URL https://www.researchsquare.com/article/rs-2569101/v1.pdf.

## Concept

The source studies crude-oil day-of-week and month-of-year seasonality across
WTI and Brent samples and reports May as the highest average-return month in
the sample. This card isolates that positive month as a clean WTI-only energy
sleeve: long-only exposure to `XTIUSD.DWX` during broker-calendar May D1 bars,
with each position flattened on the next D1 bar unless the ATR hard stop or
framework Friday close acts first.

This is deliberately different from the existing WTI April/August single-month
cards, the broad February-September seasonal allocation, WTI weekday/event/roll
sleeves, XTI/XNG baskets, WTI/Brent baskets, metal-ratio baskets, and
`QM5_12567_cum-rsi2-commodity`.

## Markets And Timeframe

- Symbol: `XTIUSD.DWX`.
- Period: D1.
- Expected trade frequency: about 18-22 trades/year.
- Backtest risk mode: `RISK_FIXED`.
- Runtime data: Darwinex MT5 OHLC and broker calendar only; no external feed.

## Entry Rules

- Evaluate only on a new D1 bar.
- Current broker-calendar D1 bar must be in May.
- Entry direction is long only: BUY `XTIUSD.DWX` at market.
- Use ATR(`strategy_atr_period`) on prior completed D1 bars for the hard stop.
- No entry if an open `XTIUSD.DWX` position already exists for this EA magic.
- No entry if `XTIUSD.DWX` spread exceeds `strategy_max_spread_points`.

## Exit Rules

- Stop loss: fixed hard SL at ATR(`strategy_atr_period`) *
  `strategy_atr_sl_mult`.
- Close the position on the first new D1 bar after entry.
- Close immediately if the current D1 bar is no longer in May.
- Also close after `strategy_max_hold_days` calendar days as a stale-position
  guard.
- Friday close remains enabled by the V5 framework.

## 8. Parameters To Test

- name: strategy_entry_month
  default: 5
  sweep_range: [5]
- name: strategy_atr_period
  default: 20
  sweep_range: [14, 20, 30]
- name: strategy_atr_sl_mult
  default: 2.25
  sweep_range: [1.5, 2.25, 3.0]
- name: strategy_max_hold_days
  default: 1
  sweep_range: [1, 2]
- name: strategy_max_spread_points
  default: 1000
  sweep_range: [700, 1000, 1500]

## Strategy Allowability Check

- [x] R1 source lineage: single research-paper source with URL.
- [x] R2 mechanical: fixed broker-calendar May, single D1 long entry, ATR stop,
  and next-bar/month-end time exit.
- [x] R3 testable: `XTIUSD.DWX` exists in `framework/registry/dwx_symbol_matrix.csv`.
- [x] R4 compliant: no ML, no adaptive PnL fitting, no grid, no martingale.

## Framework Alignment

- no_trade: D1 and `XTIUSD.DWX` guard, parameter guard, spread cap.
- trade_entry: May broker-calendar long entry.
- trade_management: first post-entry D1 bar, month-end, and max-hold exit.
- trade_close: hard ATR stop plus deterministic time exits.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-01 | APPROVED | this card |
