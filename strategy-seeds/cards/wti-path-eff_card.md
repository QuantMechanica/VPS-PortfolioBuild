---
copy_of: strategy-seeds/cards/approved/QM5_20274_wti-path-eff_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_PATHEFF12_S23
variant_id: MOP-TSMOM-2012_XTI_PATHEFF12_S23
source_id: MOP-WTI-PATHEFF-2026
ea_id: QM5_20274
slug: wti-path-eff
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-twelve-adjacent-log-return-net-to-absolute-path-efficiency-threshold-trend
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q02_ENQUEUED
q01_status: PASS
q02_status: ENQUEUED
last_updated: 2026-08-10
---

# QM5_20274 WTI Monthly Path-Efficiency Trend

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20274_wti-path-eff_card.md`.

## Hypothesis

A WTI prior-year net move that is large relative to the sum of all absolute
monthly moves may represent a more coherent oil regime than an endpoint return
alone. This is a direct crude-oil structural carrier, not a profitability or
decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes and form the twelve chronological
adjacent log returns. Let `N` be their signed sum and `P` the sum of their
absolute values. Buy when `N > 0` and `abs(N)/P >= 0.25`; sell symmetrically;
consume zero-path, zero-net, below-threshold, or invalid states flat. Renew at
the next month boundary. The canonical card locks endpoints, orientation,
numerator, denominator, threshold, persisted attempt, ATR stop, spread cap,
and lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 is approved under the durable OWNER mission decision. Q01 passed the
explicit strict compile, target build check, and P1 artifact validation on
2026-08-10. Exactly one current-binary Q02 item was enqueued below the
factory CPU ceiling: `6586fea1-87ce-4bf4-a570-f49431c50a57`, attempt 0 with
no verdict at handoff.
