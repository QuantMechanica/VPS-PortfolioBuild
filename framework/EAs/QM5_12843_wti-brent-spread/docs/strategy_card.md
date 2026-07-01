---
ea_id: QM5_12843
slug: wti-brent-spread
type: strategy
strategy_id: CME-WTI-BRENT-SPREAD-2026_S01
source_id: CME-WTI-BRENT-SPREAD-2026
source_citation: "CME Group WTI-Brent Financial Futures; ICE Brent/WTI Futures Spread; U.S. EIA Today in Energy Brent-WTI spread analysis."
source_citations:
  - type: exchange_reference
    citation: "CME Group. WTI-Brent Financial Futures."
    location: "https://www.cmegroup.com/markets/energy/crude-oil/wti-brent-ice-calendar-swap-futures.html"
    quality_tier: A
    role: primary
  - type: exchange_reference
    citation: "ICE. Brent/WTI Futures Spread."
    location: "https://www.ice.com/products/1242/Brent-WTI-Futures-Spread/data"
    quality_tier: A
    role: corroborating
  - type: government_agency_analysis
    citation: "U.S. Energy Information Administration. Today in Energy Brent-WTI spread analysis."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67424"
    quality_tier: A
    role: structural_context
sources:
  - "[[sources/CME-WTI-BRENT-SPREAD-2026]]"
concepts:
  - "[[concepts/crude-benchmark-spread]]"
  - "[[concepts/brent-wti-relative-value]]"
indicators:
  - "[[indicators/rolling-zscore]]"
  - "[[indicators/atr]]"
strategy_type_flags: [pair-spread-zscore, market-neutral-basket, mean-reversion-exit, atr-hard-stop, time-stop, low-frequency]
target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
primary_target_symbols: [XTIUSD.DWX, XBRUSD.DWX]
markets: [XTIUSD.DWX, XBRUSD.DWX]
logical_symbol: QM5_12843_WTI_BRENT_SPREAD_D1
single_symbol_only: false
period: D1
timeframes: [D1]
expected_trade_frequency: "Low-frequency D1 Brent/WTI spread package; estimate 5-12 paired packages/year before Q02 validates history and fills."
expected_trades_per_year_per_symbol: 10
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-01
g0_approval_reasoning: "R1 PASS exchange-traded CME/ICE Brent-WTI spread references plus EIA structural spread analysis; R2 PASS deterministic D1 log-spread z-score rule with ATR stops; R3 PASS XTI history exists and XBR route is already represented by QM5_12841, with Q02 required to validate XBR history sufficiency; R4 PASS no ML, grid, martingale, external runtime feed, or banned indicators."
expected_pf: 1.08
expected_dd_pct: 22.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [symbol_history_sufficiency, basket_execution, friday_close, magic_schema, risk_mode_dual]
---

# WTI-Brent Spread Reversion

See `strategy-seeds/cards/wti-brent-spread_card.md` for the approved research
card. This EA-local copy is kept for build evidence colocation.
