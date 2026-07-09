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

Approved artifact copy of `strategy-seeds/cards/xti-prod-fade_card.md`.

R1-R4 are PASS. This is a low-frequency, structural XTI energy sleeve using
official EIA field-production/WPSR lineage and deterministic D1 OHLC rules. It
does not read EIA data at runtime. It is non-duplicate versus `QM5_13028` because
it fades failed probes back inside the prior channel rather than entering
confirmed breakouts after compression.

Q01 compile/build_check PASS recorded 2026-07-09. Q02 is pending in
`D:\QM\strategy_farm\state\farm_state.sqlite` as work item
`419d5653-7116-45dd-8422-2d0ace83f3da`.
