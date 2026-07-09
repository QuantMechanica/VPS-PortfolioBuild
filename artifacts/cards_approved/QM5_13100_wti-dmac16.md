---
ea_id: QM5_13100
slug: wti-dmac16
type: strategy
strategy_id: SZAKMARY-WTI-DMAC16-2010
source_id: SZAKMARY-WTI-DMAC16-2010
source_citation: "Szakmary, Shen and Sharma (2010), Trend-following trading strategies in commodity futures: A re-examination, Journal of Banking and Finance 34(2), 409-426, DOI 10.1016/j.jbankfin.2009.08.004."
source_citations:
  - type: academic_paper
    citation: "Szakmary, A. C., Shen, Q. and Sharma, S. C. (2010). Trend-following trading strategies in commodity futures: A re-examination."
    location: "https://doi.org/10.1016/j.jbankfin.2009.08.004"
    quality_tier: A
    role: primary
  - type: official_exchange_page
    citation: "CME Group. WTI Crude Oil Futures."
    location: "https://www.cmegroup.com/markets/energy/wti-crude-oil-futures.html"
    quality_tier: A
    role: supplement
sources:
  - "[[sources/SZAKMARY-WTI-DMAC16-2010]]"
strategy_type_flags: [trend-filter-ma, signal-reversal-exit, atr-hard-stop, symmetric-long-short, news-blackout]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
markets: [commodities, energy, crude_oil]
single_symbol_only: true
logical_symbol: QM5_13100_WTI_DMAC16_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly 1/6-month DMAC state changes; estimate 1-5 entries/year before Q02 validation."
expected_trades_per_year_per_symbol: 3
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 25.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, enhancement_doctrine]
g0_approval_reasoning: "Mission-directed approval: peer-reviewed commodity trend source, deterministic monthly 1/6 moving-average state with 2.5% neutral band, WTI data available, and no ML/grid/martingale/external runtime feed."
---

# WTI Monthly 1/6 DMAC Neutral-Band Trend

Canonical approved card copy. Full card:
`strategy-seeds/cards/approved/QM5_13100_wti-dmac16_card.md`.

## Hypothesis

Slow commodity supply/demand adjustment can sustain multi-month price trends.
The EA tests the source's sparse monthly dual-moving-average rule on WTI, an
energy exposure distinct from the current XAU/SP500/NDX/XNG book.

## Rules

Trade `XTIUSD.DWX` on a D1 host. On the first bar of each broker-calendar
month, reconstruct six completed month-end closes from D1 history. The newest
close is the short value and their arithmetic mean is the long value. Hold or
enter long above the mean by more than 2.5%, short below it by more than 2.5%,
and flat inside the band. Close/reverse only at a monthly state change; every
entry has a frozen ATR hard stop and no take-profit.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one `XTIUSD.DWX` D1 setfile.
Friday close is disabled because weekly flattening would invalidate the
source's month-to-month holding rule. No live file, AutoTrading state, deploy
manifest, T_Live manifest, portfolio admission, or portfolio gate is touched.

## Non-Duplicate Boundary

This is not the M15 30/140 crude crossover, a Donchian/ADX breakout, 12-month
return-sign TSMOM, 3/9 or 6/12 return alignment, a 52-week extreme anchor,
weekly volatility-gated momentum, commodity RSI, or WTI event/calendar logic.
Its source-defined 1/6 monthly mean and 2.5% flat band are the complete state
machine.
