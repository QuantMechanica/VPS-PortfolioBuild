---
ea_id: QM5_13034
slug: xti-audcad-rspr
type: strategy
strategy_id: EIA-RBA-BOC-XTI-AUDCAD-2026_S01
source_id: EIA-RBA-BOC-XTI-AUDCAD-2026
source_citation: "EIA oil/exchange-rate working paper plus official RBA commodity-AUD and Bank of Canada oil-CAD context."
strategy_type_flags: [commodity-fx-relative-value, market-neutral-basket, return-spread-zscore, mean-reversion-exit, atr-hard-stop, time-stop, symmetric-long-short, low-frequency]
target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
basket_symbols: [XTIUSD.DWX, AUDCAD.DWX]
primary_target_symbols: [XTIUSD.DWX, AUDCAD.DWX]
single_symbol_only: false
logical_symbol: QM5_13034_XTI_AUDCAD_RSPREAD_D1
period: D1
timeframes: [D1]
expected_trade_frequency: "D1 XTI/AUDCAD return-spread z-score reversion; estimate 6-12 paired packages/year before Q02 validates synchronized history and fills."
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
expected_dd_pct: 20.0
risk_class: medium-high
ml_required: false
---

# XTI/AUDCAD D1 Return-Spread Reversion

Approved structural commodity/FX basket. Full canonical card lives at
`strategy-seeds/cards/approved/QM5_13034_xti-audcad-rspr_card.md`.

The EA trades `XTIUSD.DWX` and `AUDCAD.DWX` on D1 using
`XTI_return + beta_audcad * AUDCAD_return`. It enters at z-score extremes and
exits on z-score reversion, max-hold, Friday close, broken-package repair, or
ATR hard stops. Q02 uses the logical basket setfile
`QM5_13034_XTI_AUDCAD_RSPREAD_D1`.

Q01 build validation passed on 2026-07-07. Q02 queue evidence:
`artifacts/qm5_13034_q02_enqueue_20260707.json`.
