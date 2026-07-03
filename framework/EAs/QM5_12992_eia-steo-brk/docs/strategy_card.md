---
ea_id: QM5_12992
slug: eia-steo-brk
type: strategy
source_id: EIA-STEO-XTI-BRK-2026
sources:
  - "U.S. Energy Information Administration, Short-Term Energy Outlook, https://www.eia.gov/outlooks/steo/"
  - "U.S. Energy Information Administration, STEO release schedule, https://www.eia.gov/outlooks/steo/release_schedule.php"
  - "U.S. Energy Information Administration, STEO global oil markets, https://www.eia.gov/outlooks/steo/report/global_oil.php"
concepts:
  - "monthly-energy-information-window"
  - "crude-oil-forecast-reaction"
  - "d1-breakout-continuation"
indicators:
  - "ATR"
  - "Donchian breakout"
strategy_type_flags: [calendar-anomaly, official-release-window, channel-breakout, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_12992_XTI_STEO_BRK_D1
period: D1
expected_trade_frequency: "Monthly EIA STEO D1 proxy breakout; estimate 4-10 entries/year after range/body/breakout filters."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-03
expected_pf: 1.08
expected_dd_pct: 18.0
g0_approval_reasoning: "R1 PASS official EIA STEO source and release schedule; R2 PASS deterministic monthly release-window calendar proxy, D1 ATR-sized breakout, ATR stop/target, and time exit; R3 PASS XTIUSD.DWX available; R4 PASS no ML/grid/martingale/external runtime feed."
---

# EIA STEO WTI Breakout

See `strategy-seeds/cards/eia-steo-brk_card.md` for the canonical approved
strategy card.
