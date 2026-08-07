---
copy_of: strategy-seeds/cards/approved/QM5_20261_wti-lr-trend_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_LR12R2_S14
variant_id: MOP-TSMOM-2012_XTI_LR12R2_S14
source_id: MOP-WTI-LRTREND-2026
ea_id: QM5_20261
slug: wti-lr-trend
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-thirteen-month-end-log-price-ols-slope-with-fixed-r-squared-path-quality-gate
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-07
---

# QM5_20261 WTI Linear-Trend Quality

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20261_wti-lr-trend_card.md`.

## Hypothesis

Trade monthly WTI in the direction of the OLS slope across thirteen completed
month-end log prices only when the fixed path-fit gate is satisfied.

## Rules

The canonical card locks consecutive completed month ends, oldest-to-newest
regression orientation, the exact OLS and `R^2` formulas, a fixed `0.50` fit
threshold, one consumed attempt per month, monthly renewal, and an ATR stop.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live artifact or portfolio mutation is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Q01 is not yet run
and Q02 is not enqueued.
