---
ea_id: QM5_13037
slug: xng-prod-brk
type: strategy
strategy_id: EIA-XNG-DRYPROD-BRK-2026
source_id: EIA-XNG-DRYPROD-BRK-2026
source_citation: "U.S. Energy Information Administration. Natural Gas Monthly; Natural Gas Data; Natural Gas Dry Production table."
strategy_type_flags: [official-release-window, structural-supply, channel-breakout, trend-filter-ma, atr-hard-stop, atr-profit-target, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XNGUSD.DWX]
primary_target_symbols: [XNGUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13037_XNG_DRYPROD_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA dry-production release-window compression breakout; estimate 4-9 entries/year before Q02."
expected_trades_per_year_per_symbol: 6
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.07
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
---

# XNG Dry-Production Release-Window Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xng-prod-brk_card.md`.

The EA trades `XNGUSD.DWX` on D1. It uses official EIA Natural Gas Monthly dry
production as structural supply lineage, then trades a price-only late-month
D1 compression breakout when the signal bar closes outside a Donchian channel
in the same direction as a slow SMA slope. It limits entries to one per
calendar month.

This is not XNG RSI commodity logic, not storage report aftershock/fade/inside
day/pre-event logic, not hurricane/freeze weather logic, not LNG export demand,
not broad XNG seasonality, not month-opening range, not weekend gap, not XNG
COT, not rig-count, and not an XTI/XNG or gas/metal basket. Backtests use
`RISK_FIXED=1000`, no external runtime data, no ML, no grid, no martingale, and
no live/deploy manifest changes.
