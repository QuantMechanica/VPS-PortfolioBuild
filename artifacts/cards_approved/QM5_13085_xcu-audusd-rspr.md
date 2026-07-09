---
ea_id: QM5_13085
slug: xcu-audusd-rspr
type: strategy
strategy_id: RBA-CME-XCU-AUDUSD-RSPREAD-2026
source_id: RBA-CME-XCU-AUDUSD-RSPREAD-2026
source_citation: "Reserve Bank of Australia AUD exchange-rate driver explainer, plus CME Copper Futures and USGS Copper Statistics references."
target_symbols: [XCUUSD.DWX, AUDUSD.DWX]
basket_symbols: [XCUUSD.DWX, AUDUSD.DWX]
single_symbol_only: false
logical_symbol: QM5_13085_XCU_AUDUSD_RSPREAD_D1
period: D1
expected_trades_per_year_per_symbol: 8
g0_status: APPROVED
status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
last_updated: 2026-07-09
---

# XCU/AUDUSD D1 Return-Spread Reversion

Canonical card: `strategy-seeds/cards/xcu-audusd-rspr_card.md`.

Approved build target: `framework/EAs/QM5_13085_xcu-audusd-rspr`.

The EA trades a D1 two-leg basket on `XCUUSD.DWX` and `AUDUSD.DWX`. It computes
`XCUUSD.DWX` fixed-window log return minus `strategy_beta_audusd` times
`AUDUSD.DWX` fixed-window log return, standardizes that return spread, enters
against z-score extremes, and exits on z-score normalization, max hold, Friday
close, broken-package repair, or per-leg ATR hard stops.

Backtests use `RISK_FIXED=1000`, `RISK_PERCENT=0`, and logical symbol
`QM5_13085_XCU_AUDUSD_RSPREAD_D1`.

## Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-09 | APPROVED | this card |
| Q01 Build Validation | 2026-07-09 | PASS | `artifacts/qm5_13085_build_result.json` |
| Q02 Baseline Screening | 2026-07-09 | QUEUED | `artifacts/qm5_13085_q02_enqueue_20260709.json` |
