# QM5_41353 WTI ADF–Phillips-Perron Agreement Trend — G0 Decision

- Date: 2026-09-05
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0 approval for falsification
- EA ID: `QM5_41353` (atomically reserved)
- Slug: `wti-adf-pp-agree-tr`
- Strategy ID: `AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905_S01`

## R1–R4 decision

Source approval is recorded at
`decisions/2026-09-05_wti_monthly_adf_phillips_perron_agreement_trend_source_approval.md`.

- R1 `PASS_WITH_GOVERNED_COMPLETE_REPUTABLE_EVIDENCE`: complete hash-bound
  Wiley and peer-reviewed ADF, PP, and WTI continuation records.
- R2 `PASS`: samples, both regressions, HAC correction, inclusive boundaries,
  conjunction, side, consumed attempt, fixed risk, stop, spread, and lifecycle
  are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered native
  `XTIUSD.DWX` D1.
- R4 `PASS`: deterministic native arithmetic only; no ML, banned signal
  indicator, external runtime feed, grid, martingale, scale-in, or pyramid.

## Identity and authorization

The corrected-root scan found no exact identity across 4,833 registry rows,
1,446 cards, and 45 Wiki nodes. Standalone ADF and PP parents each omit the
other diagnostic. Existing ADF-agreement siblings use different second-state
functions. This identity requires both the 58-row lag-one ADF t statistic and
the separate 59-row, eleven-HAC-lag PP Z-tau to be at least `-2.594`; only the
completed twelve-month return chooses side.

The implementation uses slot zero, magic `413530000`, sixty completed month
ends, one consumed monthly attempt, `RISK_FIXED=1000`, frozen
`3.5*ATR(20)` stop, 1,500-point spread ceiling, next-month exit, and 40-day
stale repair. News, Friday close, and stress are off.

This decision authorizes deterministic magic allocation, branch-only non-live
V5 build, reference tests, strict Q01, and one paced Q02 enqueue if CPU
admission is clear. It grants no performance/decorrelation claim, portfolio
waiver/admission, portfolio-gate change, deployment/live manifest, `T_Live`,
AutoTrading, terminal control, or live use.
