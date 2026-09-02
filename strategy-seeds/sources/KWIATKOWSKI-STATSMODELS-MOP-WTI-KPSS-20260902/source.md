---
source_id: KWIATKOWSKI-STATSMODELS-MOP-WTI-KPSS-20260902
title: WTI monthly KPSS nonstationarity-gated trend
publisher: QuantMechanica governed synthesis from peer-reviewed and pinned scientific-computing records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_kpss_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-mkpss-tr
---

# WTI Monthly KPSS Nonstationarity-Gated Trend

## Sources Of Record And Retrieval Boundary

The executable statistical-method record is the statsmodels project's pinned
`statsmodels/tsa/stattools/_stattools.py` at commit
`2d1115dbd648b1e120a7e7454479d46481a73a9a`. The governed source router
returned `ROUTE_GITHUB_API`. The public GitHub contents API was then used to
read the complete bounded `kpss`, `_sigma_est_kpss`, and `_kpss_autolag`
implementations. The full pinned file is 141,035 bytes, Git blob
`ebe4a024bd1df5c8dab7db93d7487c7e23592cfc`, and SHA-256
`86BF64753641451C73F425E2F7E0F403A10E8609354774B73D62424118F39982`.

The pinned implementation states the null as level or trend stationarity. For
the constant-only form used here it subtracts the sample mean, sums squared
partial residual sums divided by `n^2`, estimates long-run variance with a
Bartlett-weighted Newey-West covariance sum, and divides the former by the
latter. Its constant-only critical values are `0.347`, `0.463`, `0.574`, and
`0.739` at 10%, 5%, 2.5%, and 1%. This extraction fixes an integer lag of four,
an interface explicitly accepted by the pinned implementation; neither its
automatic lag selector nor interpolated p-value enters the strategy.

The complete pinned upstream `test_stattools.py` file was also read through the
public API. It is 96,294 bytes, Git blob
`81e202b2f6d45853e50e54129d2715046f526a49`, and SHA-256
`1CD1204A2C99546C995DF2F21DE2ACC7F624C604926DBA98771B6A4DE952D85F`.
Its `TestKPSS` section checks the implementation against R/tseries values,
including fixed-lag constant and trend statistics on the macrodata real-GDP
series. No fixture observation or macroeconomic result enters this card.

Original peer-reviewed attribution is Denis Kwiatkowski, Peter C. B. Phillips,
Peter Schmidt, and Yongcheol Shin (1992), "Testing the Null Hypothesis of
Stationarity against the Alternative of a Unit Root," *Journal of
Econometrics* 54, 159-178, DOI `10.1016/0304-4076(92)90104-Y`. The citation,
null, equations, and Table-1 critical-value attribution are preserved in the
pinned implementation. No inaccessible publisher body claim is used.

The directional carrier is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The existing complete-paper record at
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves monthly own-return continuation and explicit NYMEX WTI membership.

No source tests the exact KPSS/WTI-trend conjunction, sixty completed monthly
log-price levels, a fixed four-lag long-run variance, the inclusive 10%
critical boundary as a trading gate, a Darwinex continuous CFD, fixed risk,
costs, lifecycle, activity, or portfolio correlation. Those are transparent
pre-result QuantMechanica hypotheses.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly sixty consecutive completed broker-month-end
closes `C[0]..C[59]`, oldest to newest. Current-month prices are excluded. Set
`x[t]=ln(C[t])`, `n=60`, and fixed covariance lag `L=4`.

For the constant-only level-stationarity null:

```text
mean_x = sum(x[t], t=0..59) / 60
e[t] = x[t] - mean_x
S[t] = sum(e[j], j=0..t)
eta = sum(S[t]^2, t=0..59) / 60^2

cross[k] = sum(e[t]*e[t-k], t=k..59), k=1..4
weight[k] = 1 - k/(4+1)
s_hat = (sum(e[t]^2) + 2*sum(weight[k]*cross[k], k=1..4)) / 60
KPSS = eta / s_hat
mom12 = x[59] - x[47]

BUY  iff KPSS >= 0.347 and mom12 > +1e-12
SELL iff KPSS >= 0.347 and mom12 < -1e-12
FLAT otherwise
```

Require all closes and arithmetic to be positive/finite, residual energy above
`1e-18`, `eta>=0`, and long-run variance `s_hat>1e-18`. The inclusive `0.347`
boundary is statsmodels' constant-only 10% critical value attributed to Table
1 of Kwiatkowski et al. The strategy does not interpolate a p-value, claim a
unit root, estimate integration order, or use the statistic's magnitude for
direction or sizing. Only the newest twelve-month log return assigns side.

The deterministic non-market fixtures in
`artifacts/qm5_wti_mkpss_tr_reference_fixture_20260902.json` pin a stationary
oscillatory path at `0.06048776826360729` (flat) and a trending path at
`1.302087859576069` (qualified). They validate arithmetic only and provide no
WTI, cadence, or performance evidence.

## Entry, Risk, And Lifecycle

Persist the normalized broker month as attempted before history, signal,
news, spread, quote, ATR, sizing, margin, or order gates. Never retry a
consumed month. Permit no foreign WTI exposure and no second owned position.

The only Q02 preset uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. A qualifying month opens one market position with a
frozen completed-D1 `3.5*ATR(20)` broker hard stop, no target, and an inclusive
1,500-point spread ceiling. Both news axes, legacy news, Friday close, and
stress rejection are OFF.

Close on the first processed tick in a later normalized broker month or after
forty elapsed calendar days. Missing or inconsistent symbol, ownership, side,
stop, entry time, or persisted entry-month state causes defensive strategy
closure. There is no intramonth statistic exit or flip, target, trail,
break-even move, partial close, retry, scale-in, grid, martingale, or pyramid.

## Reputable-Source Criteria

- R1: `PASS_WITH_SYNTHESIS_BOUNDARY`. Peer-reviewed original attribution,
  complete pinned scientific implementation, complete upstream method tests,
  and a governed complete peer-reviewed WTI continuation paper are preserved.
  The exact conjunction is explicitly untested.
- R2: `PASS`. Clock, sixty endpoints, logarithm orientation, mean residuals,
  partial sums, fixed lag, Bartlett weights, Newey-West long-run variance,
  inclusive source critical value, momentum side, attempt, fixed risk, hard
  stop, spread, and lifecycle are fixed before market testing.
- R3: `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`. Registered native WTI D1 data
  supplies all runtime inputs; roll, basis, financing, gaps, and broker-month
  labels remain material risks.
- R4: `PASS`. Only bounded deterministic price/calendar arithmetic and native
  V5 state are used; no trained output, prohibited signal indicator, external
  runtime feed, grid, or martingale is authorized.

## Duplicate Boundary

The corrected-root deterministic scan found no exact or fuzzy identity across
4,802 registry rows, 1,431 cards, and 45 Strategy Wiki nodes. The receipt is
`artifacts/qm5_wti_mkpss_tr_preallocation_dedup_20260902.json`.

- `QM5_41313` sums squared linear return autocorrelations. KPSS operates on
  demeaned log-price-level partial sums and a long-run-variance denominator.
- `QM5_41315` regresses squared returns on squared-return lags. KPSS neither
  squares returns nor fits a conditional-variance regression.
- `QM5_41316` counts close delay-vector pairs under the BDS construction.
  KPSS has no distance threshold, pair matrix, embedding, or BDS variance.
- Jarque-Bera and entropy families measure marginal shape or pattern
  complexity; robust-shift families compare return blocks; variance-ratio
  families normalize multi-period return variance. None uses the locked KPSS
  level-stationarity statistic.
- Pure WTI time-series momentum has no level-stationarity admission gate.
  Certified `QM5_12567` is a long-only two-day XNG oscillator pullback.

Verdict:
`CLEAN_WTI_MONTHLY_60_LOG_LEVEL_KPSS_C_LAG4_GE_0P347_GATED_12M_CONTINUATION`.

## Validation And Kill Boundary

Reference tests must independently reproduce both pinned synthetic fixtures;
prove additive log-level invariance, chronological endpoint orientation,
inclusive boundary behavior, fixed four-lag Bartlett weights, source-aligned
partial-sum and long-run-variance arithmetic, invalid/degenerate failure,
attempt-before-fallible-gate semantics, fixed risk, and next-month closure.

Retire below five completed positions in any full post-warm-up year, at zero
positions, on nonpositive governed economics, nondeterminism, or any formula,
attempt, fixed-risk, hard-stop, or lifecycle defect. No result-based change to
sample, lag, critical value, direction, stop, hold, spread, or retry is
allowed.

This approval excludes manual backtests; live/demo/shadow/stress/optimization
setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests; portfolio-gate
changes; portfolio admission; correlation waivers; and manual terminal
control. Q09 alone may establish or reject realized decorrelation.
