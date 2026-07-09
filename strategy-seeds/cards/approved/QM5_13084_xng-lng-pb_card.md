---
ea_id: QM5_13084
slug: xng-lng-pb
type: strategy
strategy_id: EIA-XNG-LNG-PB-2026
source_id: EIA-XNG-LNG-PB-2026
source_citation: "U.S. Energy Information Administration natural-gas price-factor and LNG export demand pages. URLs https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php, https://www.eia.gov/todayinenergy/detail.php?id=67004, https://www.eia.gov/todayinenergy/detail.php?id=67484, and https://www.eia.gov/naturalgas/weekly/."
source_citations:
  - type: official_energy_reference
    citation: "U.S. Energy Information Administration. Factors affecting natural gas prices."
    location: "https://www.eia.gov/energyexplained/natural-gas/factors-affecting-natural-gas-prices.php"
    quality_tier: A
    role: primary
  - type: official_energy_analysis
    citation: "U.S. Energy Information Administration. We expect Henry Hub natural gas spot prices to fall slightly in 2026 before rising in 2027. Today in Energy, 2026-01-14."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67004"
    quality_tier: A
    role: demand_growth_context
  - type: official_energy_analysis
    citation: "U.S. Energy Information Administration. U.S. natural gas exports to grow nearly 30% by 2027 as LNG facilities ramp up. Today in Energy, 2026-05-26."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=67484"
    quality_tier: A
    role: lng_export_context
  - type: official_weekly_report
    citation: "U.S. Energy Information Administration. Natural Gas Weekly Update."
    location: "https://www.eia.gov/naturalgas/weekly/"
    quality_tier: A
    role: market_context
sources:
  - "[[sources/EIA-XNG-LNG-PB-2026]]"
concepts:
  - "[[concepts/natural-gas-lng-exports]]"
  - "[[concepts/structural-demand-continuation]]"
  - "[[concepts/post-breakout-pullback]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [lng-export-demand, post-breakout-pullback, trend-continuation, atr-hard-stop, atr-profit-target, time-stop, long-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [commodities, energy, natural_gas]
single_symbol_only: true
logical_symbol: QM5_13084_XNG_LNG_PB_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Low-frequency LNG-demand-month post-breakout pullback continuation; estimate 4-8 entries/year after recent-breakout, SMA reclaim, ATR, spread, and one-entry-per-month filters."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.08
expected_dd_pct: 24.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [low_frequency_sample, natural_gas_volatility, friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "Mission-directed commodity/energy sleeve 2026-07-09: R1 PASS official EIA natural-gas price-factor, LNG export demand, and weekly market sources; R2 PASS deterministic D1 LNG-demand-month recent breakout memory plus SMA/ATR pullback reclaim entry, ATR stop/target, SMA/channel/time exits, one-position and one-entry-per-month guards; R3 PASS XNGUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed. Non-duplicate because this waits for a post-breakout pullback/reclaim after LNG demand confirmation, unlike QM5_12769 immediate compression breakout and unlike QM5_12567 RSI mean reversion."
---

# XNG LNG Export-Demand Pullback Continuation

See canonical card `strategy-seeds/cards/xng-lng-pb_card.md`.
