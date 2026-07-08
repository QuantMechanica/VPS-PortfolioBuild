---
ea_id: QM5_13074
slug: eia-jetfuel-fade
source_id: EIA-JETFUEL-SEASON-2026
status: APPROVED
pipeline_phase: Q02
target_symbols: [XTIUSD.DWX]
period: D1
---

# WTI Jet Fuel Post-Spike Failed-Rally Fade

Approved structural card for `XTIUSD.DWX` D1. It shorts failed rallies from
August 15 through October 31 after the EIA jet-fuel demand and post-spike
source packet, using only MT5 OHLC/calendar, SMA, ATR, spread, and V5 framework
state.

Source URLs:

- https://www.eia.gov/todayinenergy/detail.php?id=64786
- https://www.eia.gov/todayinenergy/detail.php?id=66004
- https://www.eia.gov/todayinenergy/detail.php?id=67764

Non-duplicate: this is short-only failed-rally exhaustion, not the existing
jet-fuel summer breakout (`QM5_12809`) or pullback continuation (`QM5_12822`).

Backtests use `RISK_FIXED=1000` and `RISK_PERCENT=0`. No live manifest,
`T_Live`, AutoTrading, portfolio gate, external runtime data, ML, grid,
martingale, or pyramiding is authorized.
