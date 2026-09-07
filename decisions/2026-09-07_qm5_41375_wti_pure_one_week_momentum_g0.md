# QM5_41375 WTI Pure One-Week Momentum — G0 Decision

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41375_wti-wmom1_card.md`
- Source approval: `decisions/2026-09-07_wti_pure_one_week_momentum_source_approval.md`
- Source-approval commit: `028c8772cd`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 `PASS_WITH_TIME_SERIES_PORT_RISK`: the complete peer-reviewed source
  defines one-week formation and one-week holding and includes light sweet
  crude oil, but its cross-sectional futures result does not transfer to one
  standalone continuous CFD.
- R2 `PASS`: exact completed-week endpoints, log-return sign, side, durable
  attempt, fixed risk, frozen stop, and next-week exit are immutable.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: native deterministic time and OHLC arithmetic only; no trained
  component, external runtime feed, banned signal, grid, martingale, or pyramid.

## Duplicate And Economic Boundary

The canonical checker found no exact or fuzzy identity across 4,855 registry
rows, 1,468 cards, and 45 Strategy Wiki nodes. `QM5_13049` adds a low-volatility
gate, `QM5_41092` adds strict weekly body dominance, and the later weekly WTI
family requires multi-week or range geometry. This card is the unconditioned
source-horizon return-sign continuation baseline.

Q02 must retire it on zero trades, fewer than five completed positions in any
full post-warm-up year, or nonpositive governed economics. There is no
optimization or parameter rescue.

## Authorization Boundary

Approval covers deterministic identity/magic allocation, V5 branch build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, one
fixed-risk backtest preset, and one paced logical Q02 enqueue only below the
hard CPU ceiling. It excludes manual backtests, portfolio admission,
correlation waivers, portfolio-gate edits, deployment, live manifests,
`T_Live`, AutoTrading, and live use.

