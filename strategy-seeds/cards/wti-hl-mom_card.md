---
copy_of: strategy-seeds/cards/approved/QM5_20276_wti-hl-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_HLRET12_S24
variant_id: MOP-TSMOM-2012_XTI_HLRET12_S24
source_id: MOP-WTI-HLRET-2026
ea_id: QM5_20276
slug: wti-hl-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-hodges-lehmann-pseudomedian-of-78-inclusive-pairwise-averages-of-twelve-completed-monthly-log-returns
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: G0
q01_status: NOT_RUN
q02_status: NOT_ENQUEUED
last_updated: 2026-08-11
---

# QM5_20276 WTI Hodges-Lehmann Return Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20276_wti-hl-mom_card.md`.

## Hypothesis

The pseudomedian of all inclusive pairwise averages of WTI's last twelve
completed monthly log returns may preserve a broad own-return trend while
reducing the influence of one extreme month. This is a direct crude-oil
structural carrier, not a profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes and form twelve chronological monthly
log returns. Form all 78 `(r[i]+r[j])/2` values for `i <= j`, sort them, and
average center indexes 38 and 39. Buy on a positive result, sell on a negative
result, and consume exact-zero or invalid states flat. Renew at the next month
boundary. The canonical card locks endpoints, orientation, inclusive pair
enumeration, sort, center indexes, persisted attempt, ATR stop, spread cap, and
lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

