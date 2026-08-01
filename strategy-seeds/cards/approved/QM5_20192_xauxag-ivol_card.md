---
card_schema_version: 2
ea_id: QM5_20192
slug: xauxag-ivol
type: strategy
strategy_id: FUERTES-MOMIVOL-2015_XAU_XAG_S03
variant_id: FUERTES-MOMIVOL-2015_XAU_XAG_S03
source_id: FUERTES-MOMIVOL-2015
status: DRAFT
g0_status: APPROVED
execution_contract_ref: strategy-seeds/cards/approved/QM5_20192_xauxag-ivol_card.md
execution_contract_status: DRAFT
created: 2026-08-01
created_by: Research+Development
last_updated: 2026-08-01
strategy_mechanic: monthly-252d-ols-idiosyncratic-volatility-rank-xau-xag-two-leg-basket
target_symbols: [XAUUSD.DWX, XAGUSD.DWX]
factor_symbols: [XTIUSD.DWX, XNGUSD.DWX, XAUUSD.DWX, XAGUSD.DWX]
logical_symbol: QM5_20192_XAU_XAG_IVOL_D1
period: D1
timeframe: D1
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
copy_of: strategy-seeds/cards/xauxag-ivol_card.md
---

# Approved Card Copy — QM5_20192_xauxag-ivol

## Hypothesis

Monthly long-low/short-high XAU/XAG factor-residual volatility may carry a
relative commodity-risk premium distinct from outright metal direction.

## Rules

The complete approved card of record is
`strategy-seeds/cards/xauxag-ivol_card.md`. Approval covers exactly one D1
logical basket: 252 synchronized returns, an equal-weight XTI/XNG/XAU/XAG
factor, separate XAU and XAG OLS residual standard deviations, long lower
IVol, short higher IVol, one shared fixed-risk budget, ATR hard stops, one
attempt per month, and next-month exit.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and one logical-basket setfile.
No live, portfolio-gate, deploy-manifest, `T_Live`, or AutoTrading action is
authorized.
