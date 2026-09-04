# QM5_41336 WTI Monthly ADF-KPSS Agreement Trend - G0 Decision

- Date: 2026-09-04
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED`
- Gate: G0, approval for falsification
- EA ID: `QM5_41336` (provisional until deterministic registry reservation)
- Slug: `wti-adf-kpss-agree-tr`
- Strategy ID: `AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904_S01`
- Source ID: `AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904`

## Authority

The current OWNER mission directs one new structural, low-frequency
commodity/energy card and build outside the certified XAU/SP500/NDX/XNG book,
permits direct WTI logic, requires a `RISK_FIXED` preset, and requests a paced
Q02 enqueue. The source was approved and committed first in `3913751920`.

This approval authorizes branch-only non-live implementation, deterministic
registry allocation, reference tests, strict Q01, and one paced Q02 enqueue
if CPU admission remains clear. It is not a performance, robustness,
decorrelation, portfolio, deployment, or live verdict.

## Card reviewed

`strategy-seeds/cards/approved/QM5_41336_wti-adf-kpss-agree-tr_card.md`

The card locks one shared sixty-endpoint monthly WTI sample, a lag-one ADF
regression, a constant-only KPSS statistic, both inclusive persistence
boundaries, a strict conjunction, twelve-month continuation side, one consumed
monthly attempt, fixed risk, frozen hard stop, and next-month lifecycle.

## R1-R4 findings

| gate | verdict | evidence |
|---|---|---|
| R1 | `PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE` | Previously approved complete ADF/KPSS method records and peer-reviewed WTI continuation record, pinned hashes, exact scopes, and non-transfer boundaries. |
| R2 | `PASS` | Month clock, endpoints, both arithmetic paths, inclusive boundaries, conjunction, side, attempt, fixed risk, stop, spread, and lifecycle are deterministic and locked. |
| R3 | `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK` | Registered native `XTIUSD.DWX` D1 data and MT5 state supply every runtime input. |
| R4 | `PASS` | Bounded deterministic prices, OLS/partial-sum/HAC arithmetic, comparisons, ATR risk, and native execution only. |

## Source and claim boundary

The parent sources supply ADF, KPSS, and monthly WTI continuation separately.
None supplies the conjunction, fixed sample/thresholds, continuous-CFD
translation, activity, economics, fixed risk, or portfolio correlation. The
two tests share observations and may not be described as independent votes.

## Non-duplicate finding

The corrected-root scan found no exact identity across 4,816 registry rows,
1,435 cards, and 45 Wiki nodes, while returning the expected fuzzy ADF and PP
neighbors. The fixture SHA-256
`5F8BB75EFB745B1AA295D503A4870359EBC192C71D04C4DD48C6C8FFFC378E2B`
pins an ADF-only qualifier rejected by KPSS and a KPSS-only qualifier rejected
by ADF. Neither `QM5_41319`, `QM5_41317`, nor `QM5_41320` implements both
required tests. Manual identity verdict:
`DISTINCT_DUAL_NULL_AGREEMENT_STATE_FROM_EITHER_SINGLE_TEST_OR_PP_STATE`.

Shared WTI continuation may still correlate. Q09 remains authoritative.

## Locked implementation contract

- Exact host/traded `XTIUSD.DWX`, D1, slot zero.
- Sixty prior consecutive completed broker-month endpoints, no current-month
  price, one shared input vector for both tests.
- ADF: 58-row intercept/no-time-trend regression with one lagged difference,
  55 residual degrees of freedom, inclusive `adf_t >= -2.594`.
- KPSS: constant-only residual partial sums, four Bartlett covariance lags,
  inclusive `kpss >= 0.347`.
- Both tests must qualify; strict twelve-month return sign chooses side.
- One attempt consumed before every fallible entry gate.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling.
- News, Friday close, and stress off; later-month or forty-day stale exit.

## Kill and safety boundary

Retire the unchanged identity on zero positions, fewer than five positions in
any full post-warm-up year, nonpositive governed economics, formula/fixture
mismatch, leakage, invalid risk, missing stop, lifecycle defect,
nondeterminism, or downstream hard failure. No result-dependent change is
authorized.

Forbidden: manual tester/backtest launch; optimization; live/demo/shadow/
stress presets; terminal control; AutoTrading; `T_Live`; deploy/live manifest;
portfolio-gate edit; correlation waiver; portfolio admission; or live use.
