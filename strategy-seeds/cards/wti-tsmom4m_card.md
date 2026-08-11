---
copy_of: strategy-seeds/cards/approved/QM5_20280_wti-tsmom4m_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_4M_S28
variant_id: MOP-TSMOM-2012_XTI_4M_S28
source_id: MOP-WTI-TSMOM4-2026
ea_id: QM5_20280
slug: wti-tsmom4m
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-exact-four-completed-broker-month-log-return-one-month-hold
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
last_updated: 2026-08-11
---

# QM5_20280 WTI Four-Month Time-Series Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20280_wti-tsmom4m_card.md`.

## Hypothesis

The sign of WTI's exact return across four completed broker months may capture
a slow crude-oil regime at a carrier horizon absent from the current registry.
WTI is not in the current XAU/SP500/NDX/XNG book. This is a falsifiable
structural-carrier hypothesis, not a profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct five consecutive
completed `XTIUSD.DWX` month-end closes. Buy when `ln(C[4]/C[0])` is positive,
sell when negative, and consume exact-zero or invalid state flat. Renew at the
next month boundary. The canonical card locks endpoint continuity, attempt
persistence, ATR stop, spread cap, and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is APPROVED and Q01 is PASS. Q02 is
`NOT_ENQUEUED_CPU_CEILING` after the binding 7/7 factory sample.
