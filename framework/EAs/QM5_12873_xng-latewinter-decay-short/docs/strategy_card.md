---
ea_id: QM5_12873
slug: xng-latewinter-decay-short
type: strategy
strategy_id: EIA-XNG-SHOULDER-2026_S03
source_id: EIA-XNG-SHOULDER-2026
source_citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24. URL https://www.eia.gov/todayinenergy/detail.php?id=22892"
source_citations:
  - type: government_energy_research
    citation: "U.S. Energy Information Administration. Natural gas consumption, production respond to seasonal changes. Today in Energy, 2015-09-24."
    location: "https://www.eia.gov/todayinenergy/detail.php?id=22892"
    quality_tier: A
    role: primary
sources:
  - "[[sources/EIA-XNG-SHOULDER-2026]]"
concepts:
  - "[[concepts/natural-gas-seasonality]]"
  - "[[concepts/shoulder-season-demand]]"
  - "[[concepts/late-winter-risk-premium-decay]]"
indicators:
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
markets: [XNGUSD.DWX]
timeframes: [D1]
logical_symbol: QM5_12873_XNG_LATEWINTER_DECAY_D1
single_symbol_only: true
period: D1
expected_trade_frequency: "Low-frequency late-winter natural-gas decay sleeve; weekly entry cadence from Feb 15 through Mar 31, about 4-9 trade attempts/year before Q02 validates fill history."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-02
expected_pf: 1.08
expected_dd_pct: 20.0
risk_class: high
ml_required: false
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [friday_close, magic_schema, risk_mode_dual]
g0_approval_reasoning: "R1 PASS official EIA natural-gas seasonality source; R2 PASS deterministic Feb 15-Mar 31 weekly short rule using winter-high drawdown, SMA slope, ATR stop, time/season exits; R3 PASS XNGUSD.DWX exists in the DWX symbol matrix; R4 PASS no ML/grid/martingale/external runtime feed."
---

# XNG Late-Winter Decay Short

See `artifacts/cards_approved/QM5_12873_xng-latewinter-decay-short.md` for the
approved strategy card. This copy is colocated with the EA for build provenance.
