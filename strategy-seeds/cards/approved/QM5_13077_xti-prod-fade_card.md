---
copy_of: strategy-seeds/cards/xti-prod-fade_card.md
ea_id: QM5_13077
slug: xti-prod-fade
type: strategy
strategy_id: EIA-XTI-FIELDPROD-FADE-2026
source_id: EIA-XTI-FIELDPROD-FADE-2026
status: APPROVED
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
period: D1
target_symbols: [XTIUSD.DWX]
primary_target_symbols: [XTIUSD.DWX]
single_symbol_only: true
logical_symbol: QM5_13077_XTI_PROD_FADE_D1
expected_trades_per_year_per_symbol: 6
expected_trade_frequency: "Weekly EIA field-production release-window failed-probe fade; roughly 3-8 entries/year before Q02 validation."
last_updated: 2026-07-09
---

# QM5_13077 XTI Field-Production Failed-Probe Fade

Approved copy of `strategy-seeds/cards/xti-prod-fade_card.md`.

This card uses official EIA weekly crude field-production and WPSR cadence as
structural lineage, then trades only `XTIUSD.DWX` D1 OHLC. It is explicitly not
`QM5_13028_xti-prod-brk`: this build fades rejected field-production-window
channel probes instead of following confirmed breakouts.

Q02 must run with the committed RISK_FIXED backtest setfile in
`framework/EAs/QM5_13077_xti-prod-fade/sets/`.
