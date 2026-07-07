---
ea_id: QM5_13035
slug: xti-prod-sup-brk
type: strategy
strategy_id: EIA-XTI-PRODSUP-BRK-2026
source_id: EIA-XTI-PRODSUP-BRK-2026
source_citation: "U.S. Energy Information Administration product supplied proxy and weekly petroleum data pages."
strategy_type_flags: [official-release-window, structural-demand, channel-breakout, trend-filter-ma, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13035_XTI_PRODSUP_BRK_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Weekly EIA product-supplied demand proxy breakout with seasonal direction filter; estimate 6-12 entries/year before Q02."
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.08
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
---

# XTI Product-Supplied Demand Breakout

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-prod-sup-brk_card.md`.

The EA trades `XTIUSD.DWX` on D1. It uses the official EIA product-supplied
consumption-proxy source family only as structural lineage, then trades a
price-only Wednesday/Thursday D1 breakout when the move agrees with the
seasonal demand map and four-week SMA slope.

This is not an inventory WPSR aftershock/fade/pre-event/inside-bar/two-event
rule, not PSM, not import/export/field-production, not OPEC/IEA/STEO/DPR/SPR/
Cushing/refinery/hurricane/rig-count/roll/expiry, not month-only WTI, not a
basket, and not RSI commodity logic. Backtests use `RISK_FIXED=1000`, no
external runtime data, no ML, no grid, no martingale, and no live/deploy
manifest changes.

Q01 build validation passed on 2026-07-07. Q02 queue evidence:
`artifacts/qm5_13035_q02_enqueue_20260707.json`; work item
`dabc19c3-f5ce-4c02-bb50-65b97463c6d1`.
