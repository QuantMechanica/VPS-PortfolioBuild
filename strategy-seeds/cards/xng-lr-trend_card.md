---
copy_of: strategy-seeds/cards/approved/QM5_20262_xng-lr-trend_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XNG_LR12R2_S15
variant_id: MOP-TSMOM-2012_XNG_LR12R2_S15
source_id: MOP-XNG-LRTREND-2026
ea_id: QM5_20262
slug: xng-lr-trend
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-xng-thirteen-month-end-log-price-ols-slope-with-fixed-r-squared-path-quality-gate
target_symbols: [XNGUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
last_updated: 2026-08-07
---

# QM5_20262 XNG Linear-Trend Quality

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20262_xng-lr-trend_card.md`.

## Hypothesis

Trade monthly XNG in the direction of the OLS slope across thirteen completed
month-end log prices only when the fixed path-fit gate is satisfied.

## Rules

The canonical card locks consecutive completed month ends, oldest-to-newest
regression orientation, the exact OLS and `R^2` formulas, a fixed `0.50` fit
threshold, one consumed attempt per month, monthly renewal, and an ATR stop.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live artifact or portfolio mutation is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Q01 passed strict
build validation; Q02 was not enqueued because the binding capacity sample
found nine governed factory terminals executing against the ceiling of seven.
Evidence: `docs/ops/evidence/2026-08-07_qm5_20262_xng_lr_trend_q01_cpu_stop.md`.
