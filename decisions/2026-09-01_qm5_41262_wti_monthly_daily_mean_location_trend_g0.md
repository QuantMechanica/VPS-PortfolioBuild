# QM5_41262 WTI Monthly Daily Mean-Location Trend - G0

- Date: 2026-09-01
- Decision owner: OWNER
- Recorded by: Codex
- Gate: G0 Strategy Card and execution-contract review
- Verdict: `APPROVED`
- EA identity: `QM5_41262_wti-mdaily-meanloc-tr`
- Strategy ID: `AI-CODEX-WTI-MDAILY-MEANLOC-20260901_S01`
- Approved card:
  `strategy-seeds/cards/approved/QM5_41262_wti-mdaily-meanloc-tr_card.md`
- Approved source:
  `strategy-seeds/sources/AI-CODEX-WTI-MDAILY-MEANLOC-20260901/source.md`
- Source approval commit: `158d6aac65`
- Identity reservation commit: `057a5ea386`

## Decision

Approve one branch-only non-live build of the locked WTI completed-month
daily mean-location continuation rule, followed by strict Q01 and one paced
Q02 enqueue if CPU admission permits. This approval does not establish
activity, profitability, robustness, decorrelation, portfolio admission,
deployment, or live suitability.

## R1-R4

- `R1 PASS`: durable AI prompt/output/source lineage plus complete-read,
  peer-reviewed monthly WTI continuation support; the exact path statistic is
  explicitly a pre-result QM interpretation.
- `R2 PASS`: exact symbol, normalized month, bounded daily observations,
  boundary proof, arithmetic mean, strict sign, attempt, risk, stop, spread,
  and lifecycle are frozen.
- `R3 PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native WTI D1 and MT5
  state supply every input; roll, financing, gaps, and broker labels remain
  falsification risks.
- `R4 PASS`: deterministic timestamps, close levels, arithmetic, comparisons,
  ATR risk, execution, deals, and terminal state only; no ML, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Locked contract

1. Exact `XTIUSD.DWX`, D1, slot 0, magic `412620000`.
2. Decide only within 180 elapsed minutes of a genuine normalized month
   transition.
3. Read 45 D1 bars, exclude current month, require all 17-23 closes from the
   immediately completed month and at least one older boundary-proving bar.
4. Require chronological timestamps and positive finite close arithmetic.
5. Compute `location=final_close/mean(completed_month_closes)-1`.
6. BUY above `1e-12`, SELL below `-1e-12`, otherwise consume the month flat.
7. Persist the month before every fallible entry gate and never retry.
8. One fixed-risk position, frozen `3.5*ATR(20,D1)` stop, no target,
   1,500-point spread ceiling, next-month exit, forty-day stale repair.
9. Both news axes and Friday close OFF; no external runtime data.

## Non-duplicate decision

The canonical receipt
`artifacts/qm5_wti_mdaily_meanloc_tr_preallocation_dedup_20260901.json`
returned `CLEAN` across 4,761 identities, 1,398 cards, and 45 Wiki nodes.
The mechanic differs from `QM5_13100` (six month-end mean), `QM5_41133`
(median daily-return sign), `QM5_41105` (high-low range close location),
`QM5_41130` (month-open residence count), and `QM5_20187` (raw monthly
return). Fixed `[110 x 19,101]` and `[90 x 19,101]` paths prove decision
disagreement with raw-return and median-return neighbors.

Verdict:
`DISTINCT_WTI_COMPLETED_MONTH_FINAL_D1_CLOSE_VERSUS_SAME_MONTH_ARITHMETIC_MEAN_CLOSE_STRICT_SIGN_CONTINUATION`.

## Conditions and excluded scope

Card lint, reference fixtures, build guard, static guardrails, strict compile,
and Q01 artifact checks must pass. Q02 receives one locked set with exactly
`RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, `ENV=backtest`,
both news axes OFF, and Friday close OFF. Stop before Q02 mutation when any
fresh CPU sample is at or above 97 percent.

Excluded: manual tester run, optimization, parameter rescue, component or
stress variants, live/demo/shadow preset, terminal control, portfolio-gate
change, deploy/live manifest, `T_Live`, AutoTrading, portfolio admission, and
correlation waiver. Unchanged Q09 alone may establish realized decorrelation.

