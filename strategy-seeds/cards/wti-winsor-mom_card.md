---
copy_of: strategy-seeds/cards/approved/QM5_20277_wti-winsor-mom_card.md
card_schema_version: 2
type: strategy
strategy_id: MOP-TSMOM-2012_XTI_WINS12_S25
variant_id: MOP-TSMOM-2012_XTI_WINS12_S25
source_id: MOP-WTI-WINSOR-2026
ea_id: QM5_20277
slug: wti-winsor-mom
status: APPROVED
g0_status: APPROVED
source_author: "Tobias J. Moskowitz; Yao Hua Ooi; Lasse Heje Pedersen"
strategy_mechanic: monthly-wti-sign-of-two-per-tail-winsorized-mean-of-twelve-completed-monthly-log-returns
target_symbols: [XTIUSD.DWX]
period: D1
pipeline_phase: Q01
q01_status: PASS
q02_status: NOT_ENQUEUED_CPU_CEILING
last_updated: 2026-08-11
---

# QM5_20277 WTI Winsorized-Mean Momentum

Canonical approved card:
`strategy-seeds/cards/approved/QM5_20277_wti-winsor-mom_card.md`.

## Hypothesis

A two-per-tail Winsorized mean of twelve disjoint completed monthly WTI
returns may preserve a broad slow oil direction while capping the influence of
four extreme months. This is a direct crude-oil structural carrier, not a
profitability or decorrelation claim.

## Rules

At each genuine broker-month transition, reconstruct thirteen consecutive
completed `XTIUSD.DWX` month-end closes, form twelve adjacent log returns, and
sort them. Replace indexes 0 and 1 with index 2 and indexes 10 and 11 with
index 9; average all twelve capped terms. Buy for a positive Winsorized mean,
sell for a negative mean, and consume exact-zero or invalid states flat. Renew
at the next month boundary. The canonical card locks endpoints, sort,
replacement indexes, divisor, persisted attempt, ATR stop, spread cap, and
lifecycle.

## Risk

Q02 uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`, one frozen `3.5 * ATR(20,D1)` hard stop, and no
take-profit. No live artifact, portfolio mutation, correlation claim, or
waiver is authorized.

## Pipeline Status

G0 and Q01 are PASS. Strict compile completed with zero errors and zero
warnings, the targeted build check has no failures or warnings, the reference
vectors pass, and P1 confirms the binary. Q02 is
`NOT_ENQUEUED_CPU_CEILING`; no screening result exists.
