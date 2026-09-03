# QM5_41320 WTI Monthly Phillips-Perron Persistence Trend - G0 Decision

- Date: 2026-09-03
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0, approval for falsification
- EA ID: `QM5_41320` (provisional until deterministic registry reservation)
- Slug: `wti-mpp-persist-tr`
- Strategy ID: `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903_S01`
- Source ID: `AI-CODEX-WTI-MPP-PERSIST-TREND-20260903`

## Authority

The current OWNER mission directs one new structural, low-frequency
commodity/energy card and build outside the certified XAU/SP500/NDX/XNG book,
permits direct WTI logic, requires a `RISK_FIXED` backtest preset, and requests
a paced Q02 enqueue. The source was approved and committed first in
`58d65c4a9f`.

This approval authorizes a branch-only non-live implementation, deterministic
registry allocation, reference tests, strict Q01, and one paced Q02 enqueue
if the CPU ceiling remains clear. It is not a performance, robustness,
decorrelation, portfolio, deployment, or live verdict.

## Card reviewed

`strategy-seeds/cards/approved/QM5_41320_wti-mpp-persist-tr_card.md`

The card locks sixty consecutive completed broker-month WTI closes, a
59-observation level AR(1) with intercept, a fixed eleven-lag Bartlett
residual long-run variance, the Phillips-Perron Z-tau correction, an inclusive
state floor of `-2.594`, a twelve-month continuation side, one consumed
monthly attempt, fixed risk, a frozen hard stop, and next-month lifecycle.

## R1-R4 findings

| gate | verdict | evidence |
|---|---|---|
| R1 | `PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE` | Complete 12-page peer-reviewed PP article plus complete peer-reviewed WTI continuation record, pinned retrieval hashes, exact read scopes, and adverse/non-transfer boundaries. |
| R2 | `PASS` | Month clock, endpoints, log orientation, AR(1), degrees of freedom, eleven Bartlett lags/weights/divisor, PP correction, boundary, side, attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 data, quotes, metadata, positions, deals, and broker calendar supply every runtime input. |
| R4 | `PASS` | Bounded deterministic prices, OLS/HAC arithmetic, comparisons, ATR risk plumbing, and native execution only; no trained output, prohibited signal indicator, external runtime feed, grid, scale-in, pyramid, or random path. |

## Source and claim boundary

Phillips and Perron supply a unit-root statistic and explicitly warn about
finite-sample distortion under negative moving-average errors. Moskowitz-
Ooi-Pedersen supply monthly WTI continuation. Neither supplies their
conjunction, the 60-level CFD sample, fixed lags, translated threshold,
activity, economics, fixed risk, or portfolio correlation.

The card may describe `pp_z_tau >= -2.594` only as a frozen persistence-state
gate. It may not claim a valid finite-sample p-value, a unit root, stationarity,
causal regime, forecast, or useful decorrelation.

## Non-duplicate finding

The corrected-root scan found no exact identity across 4,805 registry rows,
1,434 cards, and 45 Strategy Wiki nodes. It returned a `0.75` fuzzy match to
`QM5_41319_wti-madf-persist-tr`, so G0 resolves it explicitly.

The ADF neighbor uses a three-coefficient first-difference regression, one
lagged difference, 55 residual degrees of freedom, and its lagged-level
coefficient t statistic. This candidate uses a two-coefficient level AR(1),
57 residual degrees of freedom, eleven residual autocovariances, Bartlett
weights, and the PP Z-tau transformation. The pinned functional vectors prove
the arithmetic object is not interchangeable. Manual identity verdict:
`DISTINCT_PP_ZTAU_HAC_STATE_FROM_ADF_LAGGED_DIFFERENCE_STATE`.

That distinction does not establish economic independence. Both are direct-
WTI continuation hypotheses; Q09 alone may admit or correlation-reject them.

## Locked implementation contract

- Exact host/traded symbol `XTIUSD.DWX`, D1, slot zero.
- Sixty immediately prior consecutive broker-month endpoints; no current-
  month price and no fallback sample.
- Fifty-nine rows of `x[t]` on an intercept and `x[t-1]`; 57 residual degrees
  of freedom.
- Exactly eleven residual autocovariances, Bartlett weight `1-j/12`, and
  covariance divisor 59.
- Exact PP Z-tau correction, inclusive floor `-2.594`, and strict twelve-
  month return side.
- One attempt consumed before every fallible entry gate.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling.
- Both news axes, legacy news, Friday close, and stress off.
- Close at a later broker month or forty-day stale repair; malformed-position
  defensive close precedes new entry.

## Kill and safety boundary

Retire the unchanged identity on zero positions, fewer than five completed
positions in any full post-warm-up year, nonpositive governed economics,
current-month leakage, formula/oracle mismatch, invalid risk, missing stop,
malformed lifecycle, nondeterminism, or any downstream hard failure. No
result-dependent sample, lag, threshold, side, risk, stop, spread, hold, or
retry change is authorized.

Forbidden: manual tester/backtest launch; optimization; live/demo/shadow/
stress presets; terminal control; AutoTrading; `T_Live`; deploy/live manifest;
portfolio-gate edit; correlation waiver; portfolio admission; or live use.
