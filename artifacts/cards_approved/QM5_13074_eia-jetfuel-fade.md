---
ea_id: QM5_13074
slug: eia-jetfuel-fade
source_id: EIA-JETFUEL-SEASON-2026
g0_status: APPROVED
status: APPROVED
pipeline_phase: Q02
target_symbols: [XTIUSD.DWX]
period: D1
expected_trades_per_year_per_symbol: 5
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
expected_pf: 1.07
expected_dd_pct: 20.0
expected_trade_frequency: "Late jet-fuel-window D1 WTI failed-rally fade; estimate 3-8 trades/year."
strategy_type_flags: [calendar-seasonality, structural-demand, failed-rally-fade, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
single_symbol_only: true
logical_symbol: QM5_13074_XTI_JETFUEL_FADE_D1
source_citation: "U.S. Energy Information Administration jet-fuel refinery-output, consumption-slowdown, and post-spike production/margin context, 2025-2026."
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: official EIA source packet, deterministic D1 failed-rally fade, XTIUSD.DWX data available, no ML/grid/martingale/external runtime data."
created: 2026-07-09
---

# QM5_13074 EIA Jet Fuel Post-Spike Failed-Rally Fade

Approved structural card for a single-symbol `XTIUSD.DWX` D1 WTI sleeve.

Source lineage:

- EIA, "Jet fuel made up a record share of U.S. refinery output in 2024",
  March 24, 2025, https://www.eia.gov/todayinenergy/detail.php?id=64786.
- EIA, "U.S. jet fuel consumption growth slows after air travel recovers from
  pandemic slowdown", August 26, 2025,
  https://www.eia.gov/todayinenergy/detail.php?id=66004.
- EIA, "U.S. jet fuel production rises after prices doubled in March", June 8,
  2026, https://www.eia.gov/todayinenergy/detail.php?id=67764.

Mechanization: August 15-October 31 short-only D1 failed-rally rejection on
`XTIUSD.DWX`, gated by flat/down SMA trend, ATR hard stop, Donchian/date/time
exits, one magic slot, RISK_FIXED backtest setfile. No EIA/runtime external
feed, ML, grid, martingale, live manifest, portfolio gate, or AutoTrading
changes.

Build/Q02 evidence:

- Q01 build validation PASS: `artifacts/qm5_13074_build_result.json`.
- Q02 baseline screening QUEUED: `artifacts/qm5_13074_q02_enqueue_20260709.json`
  (`d9753f99-47ed-4e88-bc10-5bfa8ced88fc`).
