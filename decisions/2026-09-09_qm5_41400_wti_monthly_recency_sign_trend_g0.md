# QM5_41400 WTI Monthly Recency-Sign Trend — G0

- Date: 2026-09-09
- OWNER authority: current commodity/energy sleeve mission
- Card: `strategy-seeds/cards/approved/QM5_41400_wti-mrecency-sign-tr_card.md`
- Source approval: `decisions/2026-09-09_wti_monthly_recency_sign_trend_source_approval.md`
- Decision: `APPROVED`
- Execution contract: `APPROVED` for branch-only non-live Q01/Q02

## Gate Findings

- R1 `PASS_WITH_RECENCY_SIGN_TRANSLATION_RISK`: the complete-read,
  peer-reviewed Moskowitz-Ooi-Pedersen record supports WTI monthly own-return
  continuation and the twelve-lag horizon. Fixed chronological sign weights
  and the absolute-18 boundary are explicit untested QM translations.
- R2 `PASS`: the card fixes the month clock, completed endpoints, return
  orientation, zero rejection, weights `1..12`, total 78, score, inclusive
  boundary, side, attempt persistence, fixed risk, ATR stop, spread, and
  next-month lifecycle.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 and
  native MT5 state provide every runtime input.
- R4 `PASS`: deterministic price/time/sign/integer arithmetic and ATR risk
  plumbing only; no ML, banned signal, external feed, grid, martingale,
  scale-in, or pyramid.

## Duplicate And Frequency Findings

The canonical preallocation receipt scanned 4,880 registry identities, 1,491
cards, and 45 Wiki nodes. There is no exact collision. The single fuzzy match,
`QM5_41273`, ranks absolute return magnitudes; QM5_41400 uses no magnitude or
sort and fixes each sign's weight solely by chronological age. `QM5_20278`
weights magnitudes, while `QM5_13150` equally counts positive signs.

Exact enumeration admits 2,124 of 4,096 sign paths at `|S|>=18`, a market-free
6.22265625 states per twelve attempts. Q02 must retire the identity below five
completed positions in any full post-warm-up year.

## Authorization Boundary

Approved for deterministic magic allocation, one branch-only V5 build,
reference fixtures, the mandatory framework-input-pin audit, strict Q01, and
one paced Q02 enqueue below the CPU ceiling. No manual backtest, optimization,
portfolio gate/admission, correlation waiver, deployment, live manifest,
`T_Live`, AutoTrading, or live use is authorized.
