---
ea_id: QM5_13038
slug: xti-dpr-fade
type: strategy
strategy_id: EIA-DPR-XTI-MOM-2026_S02
source_id: EIA-DPR-XTI-MOM-2026
source_citation: "U.S. Energy Information Administration. Drilling Productivity Report and DPR FAQ."
strategy_type_flags: [calendar-anomaly, official-release-window, failed-breakout-fade, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX]
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

Approved structural XTI D1 sleeve. Full canonical card lives at
`strategy-seeds/cards/approved/QM5_13038_xti-dpr-fade_card.md`.

The EA trades `XTIUSD.DWX` on D1 using a price-only mid-month failed Donchian
breakout fade around the official EIA DPR source lineage, with ATR range/body/
tail confirmation, SMA stretch, ATR stop/target, and SMA mean-reversion exit.
Q01/Q02 evidence: `artifacts/qm5_13038_build_result.json` and
`artifacts/qm5_13038_q02_enqueue_20260707.json`.

Entry signal: short when the prior completed D1 bar inside the DPR proxy window
breaches the prior Donchian high, closes back below that high, closes below its
open, remains above SMA, and leaves an ATR-sized upper tail; long is the mirror
case below the prior Donchian low. Exit on ATR stop/target, SMA mean-reversion,
max-hold, and framework Friday close. Sizing/risk for Q02 is `RISK_FIXED=1000`
with `RISK_PERCENT=0`.
