---
ea_id: QM5_13074
slug: eia-jetfuel-fade
type: strategy
source_id: EIA-JETFUEL-SEASON-2026
source_citation: "U.S. Energy Information Administration jet-fuel refinery-output, consumption-slowdown, and post-spike production/margin context, 2025-2026."
sources:
  - "[[sources/EIA-JETFUEL-SEASON-2026]]"
concepts:
  - "[[concepts/jet-fuel-refinery-yield]]"
  - "[[concepts/jet-fuel-demand-slowdown]]"
  - "[[concepts/post-spike-exhaustion]]"
indicators:
  - "[[indicators/donchian-channel]]"
  - "[[indicators/sma]]"
  - "[[indicators/atr]]"
strategy_type_flags: [calendar-seasonality, structural-demand, failed-rally-fade, trend-filter-ma, atr-hard-stop, time-stop, short-only, low-frequency]
target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13074_XTI_JETFUEL_FADE_D1
period: D1
expected_trade_frequency: "Late jet-fuel-window D1 WTI failed-rally fade; estimate 3-8 trades/year."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
expected_pf: 1.07
expected_dd_pct: 20.0
g0_approval_reasoning: "Mission-directed G0 approval 2026-07-09: official EIA source packet, deterministic D1 failed-rally fade, XTIUSD.DWX data available, no ML/grid/martingale/external runtime data."
---

# WTI Jet Fuel Post-Spike Failed-Rally Fade

Approved structural card for `XTIUSD.DWX` D1. It shorts late-window failed
rallies from August 15 through October 31 after the EIA jet-fuel demand and
post-spike source packet, using only MT5 OHLC/calendar, SMA, ATR, spread, and
V5 framework state.

Non-duplicate: this is not `QM5_12809_eia-jetfuel-brk` summer upside breakout
and not `QM5_12822_eia-jetfuel-pb` summer pullback continuation. It is
short-only exhaustion/fade logic.

Q02 risk mode must remain `RISK_FIXED=1000`, `RISK_PERCENT=0`. No live
manifest, `T_Live`, AutoTrading, portfolio gate, external runtime data, ML,
grid, martingale, or pyramiding is authorized.

Build/Q02 evidence:

- Q01 build validation PASS: `artifacts/qm5_13074_build_result.json`.
- Q02 baseline screening QUEUED: `artifacts/qm5_13074_q02_enqueue_20260709.json`
  (`d9753f99-47ed-4e88-bc10-5bfa8ced88fc`).
