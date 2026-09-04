---
source_id: AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904
title: WTI monthly ADF-KPSS persistence-agreement trend
publisher: QuantMechanica governed synthesis from approved ADF, KPSS, and WTI continuation sources
source_type: ai_originated_peer_reviewed_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-04_wti_monthly_adf_kpss_agreement_trend_source_approval.md
parent_source_ids:
  - AI-CODEX-WTI-MADF-PERSIST-TREND-20260903
  - KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902
  - MOP-TSMOM-2012
created: 2026-09-04
created_by: Research+Development
cards_extracted:
  - wti-adf-kpss-agree-tr
---

# WTI Monthly ADF-KPSS Persistence-Agreement Trend

## Authority and bounded read

The current explicit OWNER mission authorizes one new structural,
low-frequency commodity/energy card and non-live build outside the certified
XAU/SP500/NDX/XNG book. It expressly permits direct WTI logic, requires a
fixed-risk backtest preset, and requests one paced Q02 enqueue.

No new external source is imported. The complete local evidence chain is
pinned in `retrieval_route_20260904.json` and reuses three previously approved
and completely read repository sources:

1. Chan's lag-one, constant/no-time-trend augmented Dickey-Fuller mechanics
   from `AI-CODEX-WTI-MADF-PERSIST-TREND-20260903`;
2. Kwiatkowski-Phillips-Schmidt-Shin constant-only KPSS mechanics and the
   pinned statsmodels arithmetic record from
   `KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902`;
3. Moskowitz-Ooi-Pedersen monthly own-return continuation and explicit NYMEX
   WTI membership from `MOP-TSMOM-2012`.

ADF and KPSS have opposite null hypotheses. The approved synthesis uses them
only as a conservative agreement classifier: the ADF boundary must not show
strong negative error correction and the KPSS boundary must reject the locked
constant-level-stationarity state. This conjunction is not supplied or tested
by any parent source.

## Locked hypothesis

WTI supplies physical energy exposure through production, storage, transport,
refining, producer hedging, geopolitics, and end demand. These drivers are
absent from the certified index/metal carriers and differ from XNG's weather
and storage sensitivity. The falsifiable hypothesis is that a completed
twelve-month WTI move is suitable for one more broker month of continuation
only when two non-equivalent monthly price-level tests agree on the locked
persistence state.

Agreement does not prove a unit root, nonstationarity, persistence,
predictability, profitability, or portfolio independence. The two tests share
the same sixty observations and are not independent votes. Q02 owns activity
and economics; Q09 alone owns realized overlap.

## Locked sample

At the first executable `XTIUSD.DWX` D1 tick after a genuine normalized broker
month transition, reconstruct exactly sixty consecutive completed
broker-month-end closes `C[0..59]`, oldest to newest, and set
`x[t]=ln(C[t])`. Exclude every current-month price. Reject missing, duplicate,
nonconsecutive, nonchronological, nonpositive, nonfinite, or stale endpoints.

## ADF component

For `t=2..59`, form 58 observations:

```text
y[t] = x[t]-x[t-1]
z[t] = x[t-1]
w[t] = x[t-1]-x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
```

Using centered 58-row cross-products:

```text
det = Szz*Sww-Szw^2
gamma = (Szy*Sww-Swy*Szw)/det
phi = (Swy*Szz-Szy*Szw)/det
alpha = mean(y)-gamma*mean(z)-phi*mean(w)
SSE = sum((y-alpha-gamma*z-phi*w)^2)
s2 = SSE/55
se_gamma = sqrt(s2*Sww/det)
adf_t = gamma/se_gamma
```

Require `Szz>1e-18`, `Sww>1e-18`,
`det>1e-12*Szz*Sww`, `SSE>1e-18`, `s2>0`, and
`se_gamma>1e-18`. The ADF component qualifies only when
`adf_t >= -2.594`, inclusive.

## KPSS component

Let `mean_x=sum(x)/60`, `e[t]=x[t]-mean_x`, and
`S[t]=sum(e[j],j=0..t)`:

```text
eta = sum(S[t]^2,t=0..59)/3600
cross[k] = sum(e[t]*e[t-k],t=k..59), k=1..4
weight[k] = 1-k/5
s_hat = (sum(e[t]^2)+2*sum(weight[k]*cross[k],k=1..4))/60
kpss = eta/s_hat
```

Require residual energy above `1e-18`, finite `eta>=0`, and
`s_hat>1e-18`. The KPSS component qualifies only when
`kpss >= 0.347`, inclusive.

## Agreement and side

```text
mom12 = x[59]-x[47]

BUY  iff adf_t >= -2.594 and kpss >= 0.347 and mom12 > +1e-12
SELL iff adf_t >= -2.594 and kpss >= 0.347 and mom12 < -1e-12
FLAT otherwise
```

Only `mom12` chooses side. Neither statistic nor return magnitude changes
risk. There is no fallback, p-value interpolation, autolag, deterministic
time trend, alternative covariance lag, or result-dependent threshold.

The non-market fixture contains four functional paths: persistent up and down
paths pass both gates; one path passes ADF alone but fails KPSS; one passes
KPSS alone but fails ADF; a stationary oscillatory path fails both. The two
single-gate disagreement paths prove that the conjunction is not an alias of
either parent EA.

## Attempt, execution, risk, and lifecycle

Persist the normalized broker month as attempted before history, arithmetic,
news, spread, quote, ATR, sizing, margin, or submission. Never retry a month.
Permit neither foreign WTI exposure nor more than one owned position.

Use exactly `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. Attach a frozen `3.5*ATR(20,D1)` broker hard stop and no
target. Require spread in `[0,1500]` points. Both news axes, legacy news,
Friday close, and stress rejection are off. Close on the first processed tick
in a later normalized broker month or after forty calendar days as stale
repair. Close malformed owned exposure defensively. No intramonth statistic
exit or flip, target, trail, break-even, partial close, scale-in, grid,
martingale, or pyramid is permitted.

## Reputable-source criteria

- **R1 — PASS_WITH_GOVERNED_COMPLETE_PARENT_EVIDENCE.** The source reuses
  approved, complete local records for a published trading book's ADF
  specification, the peer-reviewed KPSS method plus pinned scientific
  implementation/tests, and the peer-reviewed WTI continuation paper. Exact
  parent hashes and claim boundaries are pinned.
- **R2 — PASS.** The sample, two complete arithmetic paths, inclusive
  boundaries, conjunction, side, attempt, risk, stop, spread, and lifecycle
  are deterministic and locked.
- **R3 — PASS_WITH_CONTINUOUS_CFD_BASIS_RISK.** Registered native
  `XTIUSD.DWX` D1 history and MT5 state supply every runtime input.
- **R4 — PASS.** Only bounded timestamps, completed prices, logarithms, OLS,
  partial sums, Bartlett covariance arithmetic, comparisons, ATR risk, and
  native execution are used; no trained output, prohibited signal indicator,
  external runtime feed, random path, grid, or martingale exists.

## Non-duplicate boundary

The corrected-root scan in
`artifacts/qm5_wti_adf_kpss_agree_tr_preallocation_dedup_20260904.json`
found no exact identity across 4,816 registry rows, 1,435 cards, and 45 Wiki
nodes. It returned expected fuzzy neighbors `QM5_41319` (ADF) and `QM5_41320`
(Phillips-Perron), requiring manual resolution.

`QM5_41319` admits every ADF-qualified path regardless of KPSS. This identity
also requires the distinct KPSS demeaned-level partial-sum/lag-four
long-run-variance boundary. `QM5_41317` admits every KPSS-qualified path
regardless of ADF; this identity also requires the distinct lag-one
error-correction regression. `QM5_41320` uses a lag-zero level AR(1) and an
eleven-lag Phillips-Perron correction, not either component conjunction. The
fixture pins both disagreement directions. Manual identity verdict:
`DISTINCT_DUAL_NULL_AGREEMENT_STATE_FROM_EITHER_SINGLE_TEST_OR_PP_STATE`.

The WTI continuation carrier remains shared and may be highly correlated with
its neighbors. No identity decision waives Q09.

## Claim, kill, and safety boundary

Q02 retires the unchanged identity on zero positions, fewer than five
completed positions in any full post-warm-up year, nonpositive governed
economics, any formula/fixture mismatch, current-month leakage, invalid fixed
risk, missing stop, malformed lifecycle, nondeterminism, or downstream hard
failure. No failed result may change the sample, lag, threshold, side, risk,
stop, spread, hold, or retry rule.

Authorized after G0 and clean allocation: one branch-only non-live V5 build,
independent reference tests, strict Q01, one fixed-risk preset, and one paced
Q02 item while the host CPU admission ceiling is clear. Excluded: manual
backtests, optimization, live/demo/shadow/stress presets, terminal control,
portfolio-gate edits, correlation waivers, portfolio admission, deploy/live
manifests, `T_Live`, AutoTrading, and live use.
