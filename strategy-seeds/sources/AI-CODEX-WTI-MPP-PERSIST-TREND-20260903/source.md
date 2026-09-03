---
source_id: AI-CODEX-WTI-MPP-PERSIST-TREND-20260903
title: WTI monthly Phillips-Perron persistence-gated trend
publisher: QuantMechanica governed synthesis from a complete peer-reviewed econometrics paper and complete peer-reviewed WTI continuation record
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-03_wti_monthly_pp_persistence_trend_source_approval.md
parent_source_ids:
  - PHILLIPS-PERRON-1988
  - MOP-TSMOM-2012
created: 2026-09-03
created_by: Research+Development
cards_extracted:
  - wti-mpp-persist-tr
---

# WTI Monthly Phillips-Perron Persistence-Gated Trend

## Approval and complete read

The durable source approval is
`decisions/2026-09-03_wti_monthly_pp_persistence_trend_source_approval.md`.
The current explicit OWNER mission authorizes one new structural,
low-frequency commodity/energy sleeve, expressly permits direct WTI logic,
requires fixed-risk backtests, and requests one paced Q02 enqueue.

The complete retrieval record is `retrieval_route_20260903.json`. Phillips
and Perron (1988), *Biometrika* 75(2), 335-346, DOI
`10.1093/biomet/75.2.335`, was read in full: all 12 journal pages. The article
develops nuisance-parameter corrections for Dickey-Fuller coefficient and
t statistics using consistent long-run-variance estimates. Its regression
with a fitted intercept, non-parametric residual covariance correction, and
Z-tau statistic provide the state calculation below.

The paper also reports a material adverse result. With strongly negative
moving-average errors, its Z tests show appreciable finite-sample size
distortion and are not recommended. That limitation is carried into the kill
boundary; a fixed 60-level CFD sample cannot be represented as a valid unit-
root diagnosis.

Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics* 104(2),
228-250, documents monthly own-return continuation over liquid futures and
explicitly includes NYMEX WTI. It does not use a PP filter. Phillips and
Perron do not propose a trading strategy. Neither source validates this
conjunction, continuous-CFD transport, risk, costs, activity, profit, or
portfolio overlap.

## Locked hypothesis

WTI carries supply, storage, transport, refining, producer-hedging,
geopolitical, and end-demand exposures absent from the certified
XAU/SP500/NDX/XNG book and different from XNG weather/storage mechanics. The
hypothesis is that a completed twelve-month WTI move is more suitable for a
one-month continuation attempt when a lag-zero Phillips-Perron regression
does not show a strongly mean-reverting price-level state.

This is a state gate, not proof of a unit root, persistence, trend,
predictability, independence, or decorrelation. Only the completed twelve-
month return chooses direction; no statistic magnitude changes risk.

## Locked formula

On the first executable D1 tick after a genuine normalized broker-month
transition, reconstruct exactly sixty consecutive completed broker-month-end
closes `C[0..59]`, oldest to newest, and set `x[t]=ln(C[t])`. Exclude all
current-month prices.

Fit 59 rows with an intercept and no deterministic time trend:

```text
lhs[i] = x[i+1], rhs[i] = x[i], i=0..58
lhs = alpha + rho*rhs + u
n=59, k=2, residual_dof=57
```

Compute centered OLS, then a fixed eleven-lag Bartlett/Newey-West residual
long-run variance:

```text
Sxx    = sum((rhs-mean(rhs))^2)
Sxy    = sum((rhs-mean(rhs))*(lhs-mean(lhs)))
rho    = Sxy/Sxx
alpha  = mean(lhs)-rho*mean(rhs)
u[i]   = lhs[i]-alpha-rho*rhs[i]
SSE    = sum(u[i]^2)
s2     = SSE/57
s      = sqrt(s2)
gamma0 = SSE/59
se_rho = sqrt(s2/Sxx)

for j=1..11:
  weight[j] = 1-j/12
  gamma[j]  = sum(i=j..58, u[i]*u[i-j])/59
lambda2 = gamma0 + 2*sum(j=1..11, weight[j]*gamma[j])
lambda  = sqrt(lambda2)
raw_tau = (rho-1)/se_rho
pp_z_tau = sqrt(gamma0/lambda2)*raw_tau
           - 0.5*((lambda2-gamma0)/lambda)*(59*se_rho/s)
mom12 = x[59]-x[47]
```

Require all inputs and outputs finite, `Sxx>1e-18`, `SSE>1e-18`, `s2>0`,
`gamma0>1e-18`, `lambda2>1e-18`, `se_rho>1e-18`, and `s>1e-18`.

```text
BUY  iff pp_z_tau >= -2.594 and mom12 > +1e-12
SELL iff pp_z_tau >= -2.594 and mom12 < -1e-12
FLAT otherwise
```

The inclusive `-2.594` boundary is frozen as a weak-error-correction state
line. The article establishes that PP Z-tau shares the corresponding
Dickey-Fuller limiting distribution; this card does not claim that the
rounded boundary is a valid finite-sample p-value for 60 CFD levels.

## Attempt, execution, risk, and lifecycle

Persist the normalized broker month as attempted before history, signal,
news, spread, quote, ATR, sizing, margin, or submission. A rejected or flat
month is never retried. Permit no foreign WTI position and at most one owned
position.

Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, a frozen
completed-D1 `3.5*ATR(20)` broker hard stop, no target, and an inclusive
1,500-point spread ceiling. Both news axes, legacy news, Friday close, and
stress rejection are off. Close at the first processed tick in a later
broker month or after forty calendar days. Close malformed owned exposure
defensively. No intramonth statistic exit or flip, target, trail, break-even,
partial close, scale-in, grid, martingale, or pyramid is allowed.

## Reputable-source criteria

- **R1 — PASS_WITH_AI_SYNTHESIS_AND_COMPLETE_PEER_REVIEWED_EVIDENCE.** The
  lineage binds a complete 12-page peer-reviewed econometrics article, a
  complete governed peer-reviewed WTI continuation record, exact URLs,
  hashes, read scopes, and adverse/non-transfer boundaries.
- **R2 — PASS.** Month clock, endpoints, log orientation, 59-row intercept
  AR(1), 57 degrees of freedom, eleven Bartlett lags, covariance divisor,
  PP correction, inclusive state line, continuation side, attempt, fixed
  risk, hard stop, spread, and lifecycle are mechanical and locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input.
- **R4 — PASS.** Deterministic bounded price/calendar/OLS/HAC arithmetic and
  native V5 execution only; no trained output, banned signal indicator,
  external runtime feed, grid, martingale, scale-in, pyramid, or random path.

## Non-duplicate boundary

The corrected-root scan at
`artifacts/qm5_wti_mpp_persist_tr_preallocation_dedup_20260903.json` found no
exact identity across 4,805 registry rows, 1,434 cards, and 45 Wiki nodes. It
correctly returned one fuzzy neighbor, `QM5_41319_wti-madf-persist-tr`, for
manual review.

The two identities share the WTI monthly continuation carrier but not the
state calculation. `QM5_41319` fits first differences on a lagged level and
one lagged difference, with three coefficients, 55 residual degrees of
freedom, and the uncorrected lagged-level coefficient t-statistic. This rule
fits a lag-zero level AR(1), with two coefficients, 57 residual degrees of
freedom, and transforms its raw t ratio using eleven residual autocovariances
and Bartlett weights. A path can therefore produce different gate decisions.

The independent receipt pins the exact PP information object against
`arch==8.0.0`: persistent up and down paths qualify; a mean-reverting path is
flat. Manual verdict:
`DISTINCT_PP_ZTAU_HAC_STATE_FROM_ADF_LAGGED_DIFFERENCE_STATE`.
This is only an implementation-identity decision. It does not claim the two
return streams will be economically distinct; Q09 remains authoritative.

## Claim, kill, and safety boundary

Q02 retires the unchanged identity on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, formula/oracle mismatch, current-month leakage, invalid fixed
risk, missing hard stop, malformed lifecycle, or nondeterminism. Negative
residual autocorrelation and the paper's finite-sample warning are explicit
falsification risks. No sample, lag, threshold, side, risk, stop, spread,
hold, or retry rule may change after observing a result.

This packet authorizes one Strategy Card, deterministic identity and magic
allocation, one branch-only non-live V5 build, independent tests, strict Q01,
and one paced Q02 enqueue while CPU admission remains clear. It authorizes no
manual backtest, optimization, live/demo/shadow/stress preset, terminal
control, portfolio-gate edit, correlation waiver, portfolio admission,
deploy/live manifest, `T_Live`, AutoTrading, or live use.
