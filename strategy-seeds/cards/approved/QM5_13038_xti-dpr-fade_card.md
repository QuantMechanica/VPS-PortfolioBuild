---
ea_id: QM5_13038
slug: xti-dpr-fade
type: strategy
strategy_id: EIA-DPR-XTI-MOM-2026_S02
source_id: EIA-DPR-XTI-MOM-2026
source_citation: "U.S. Energy Information Administration. Drilling Productivity Report and DPR FAQ."
strategy_type_flags: [calendar-anomaly, official-release-window, failed-breakout-fade, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13038_XTI_DPR_FADE_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "Monthly EIA DPR/shale-production proxy failed-breakout fade; estimate 3-7 entries/year before Q02."
expected_trades_per_year_per_symbol: 5
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-07
expected_pf: 1.06
expected_dd_pct: 18.0
risk_class: medium-high
ml_required: false
---

# XTI DPR Failed-Breakout Fade

Canonical approved card copy. Full source card lives at
`strategy-seeds/cards/xti-dpr-fade_card.md`.

The EA trades `XTIUSD.DWX` on D1. It uses the official EIA DPR source family
only as structural lineage, then trades a price-only mid-month failed Donchian
breakout fade when the proxy bar breaches and reclaims the channel with an ATR
range/body/tail and SMA stretch.

This is not `QM5_12996_xti-dpr-mom`, because it fades failed DPR proxy
breakouts instead of following confirmed DPR proxy breakouts. It is also not
WPSR/STEO/OPEC/IEA/Cushing/refinery/rig-count/roll/expiry/month-only/weekday/
RSI/basket/metals logic. Backtests use `RISK_FIXED=1000`, no external runtime
data, no ML, no grid, no martingale, and no live/deploy manifest changes.

Q01 build validation pending at card approval. Q02 queue evidence will be
recorded in `artifacts/qm5_13038_q02_enqueue_20260707.json`.
