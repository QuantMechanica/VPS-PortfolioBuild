# QM5_41378 WTI Half-Year Weekly Momentum — G0 Decision

- Date: 2026-09-07
- Decision owner: OWNER
- Recorded by: Codex
- Card: `strategy-seeds/cards/approved/QM5_41378_wti-wmom265_card.md`
- Source approval: `decisions/2026-09-07_wti_halfyear_weekly_momentum_source_approval.md`
- Verdict: `APPROVED`
- Execution contract: `APPROVED` for branch build and non-live pipeline only

## Gate Decision

- R1 `PASS_WITH_WEAK_RAW_AND_FACTOR_SPANNING_EVIDENCE`: the peer-reviewed
  complete-read source defines `CMOM26,5` and includes light sweet crude oil,
  while weak raw significance and adverse carry/UMD spanning are retained.
- R2 `PASS`: 26 consecutive completed weekly packages, exact `t-26..t-5`
  endpoints, recent-four-week exclusion, side, durable attempt, fixed risk,
  frozen stop, and next-week exit are immutable.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native XTIUSD.DWX D1
  history supplies every runtime market input.
- R4 `PASS`: deterministic timestamp/OHLC arithmetic only; no trained
  component, external runtime feed, banned signal, grid, martingale, or
  pyramid.

## Duplicate And Economic Boundary

The only automatic matches are expected short-horizon same-paper siblings.
This identity alone excludes `t-4..t-1` and uses the exact source-defined
22-week block `t-26..t-5` on a weekly decision and hold clock. Monthly WTI
trend cards have different endpoints and lifecycle. Q02 retires on zero
trades, fewer than five completed positions in any full post-warm-up year, or
nonpositive governed economics. There is no optimization or parameter rescue.

## Authorization Boundary

Approval covers deterministic identity/magic allocation, V5 branch build,
mandatory PACER input-pin audit before compile enqueue, strict Q01, one fixed-
risk backtest preset, and one paced logical Q02 enqueue only below the hard CPU
ceiling. It excludes manual backtests, portfolio admission, correlation
waivers, portfolio-gate edits, deployment, live manifests, `T_Live`,
AutoTrading, and live use.
