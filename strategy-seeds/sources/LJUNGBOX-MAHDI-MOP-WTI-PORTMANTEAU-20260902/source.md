---
source_id: LJUNGBOX-MAHDI-MOP-WTI-PORTMANTEAU-20260902
title: WTI monthly Ljung-Box-portmanteau-gated trend
publisher: QuantMechanica governed synthesis from peer-reviewed statistical and trading records
source_type: ai_originated_composite_bounded_mechanization
status: approved_source_complete
approval_basis: decisions/2026-09-02_wti_monthly_ljung_box_trend_source_approval.md
created: 2026-09-02
created_by: Research+Development
parent_source_ids:
  - MOP-TSMOM-2012
cards_extracted:
  - wti-ljungbox-tr
---

# WTI Monthly Ljung-Box-Portmanteau-Gated Trend

## Sources Of Record And Retrieval Boundary

The statistical-method record is Esam Mahdi (2016), "Portmanteau test
statistics for seasonal serial correlation in time series models,"
*SpringerPlus* 5, 1485, DOI `10.1186/s40064-016-3167-4`. The complete
open-access paper was read end to end from PubMed Central. Its background
defines residual autocorrelation and records the Ljung-Box finite-sample
modification:

```text
r[k] = sum((x[t]-mean)*(x[t-k]-mean), t=k..n-1)
       / sum((x[t]-mean)^2, t=0..n-1)
Q(m) = n*(n+2) * sum(r[k]^2/(n-k), k=1..m)
```

Under the diagnostic null, the reference distribution is asymptotically
chi-square, adjusted for fitted parameters where applicable. The paper's
simulations emphasize that convergence is sample-size dependent, and its
scope is model-residual adequacy. This extraction uses the formula only as a
transparent omnibus path-state statistic on raw completed-month WTI returns;
it does not import a hypothesis-test conclusion or p-value.

Original attribution is G. M. Ljung and George E. P. Box (1978), "On a
measure of lack of fit in time series models," *Biometrika* 65(2), 297-303,
DOI `10.1093/biomet/65.2.297`. Only Oxford University Press metadata and its
abstract were used for that record. An unapproved mirror returned
`DEFERRED:SOURCE_POLICY` from the governed router and is explicitly excluded.

The continuation carrier is Moskowitz, Ooi, and Pedersen (2012), "Time Series
Momentum," *Journal of Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The existing governed complete-paper record
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
`C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`,
preserves the monthly own-return continuation finding and explicit NYMEX WTI
membership.

No source tests the Ljung-Box/WTI-trend conjunction, raw rather than fitted
residual returns, a 48-return sample, six lags, the chi-square median as a
state boundary, the Darwinex continuous CFD, fixed-dollar risk, costs,
activity, or portfolio correlation. Every conjunction and execution choice
below is a transparent pre-result QM hypothesis.

## Exact Mechanic

On the first executable `XTIUSD.DWX` D1 tick after a genuine broker-month
transition, reconstruct exactly forty-nine consecutive completed broker-month
end closes `C[0]..C[48]`, oldest to newest. Exclude current-month prices and
form forty-eight chronological adjacent log returns:

```text
x[i] = ln(C[i+1] / C[i]), i=0..47
mean = sum(x[i]) / 48
y[i] = x[i] - mean
den = sum(y[i]^2, i=0..47)
rho[k] = sum(y[i]*y[i-k], i=k..47) / den, k=1..6
Q6 = 48*50 * sum(rho[k]^2/(48-k), k=1..6)
mom12 = sum(x[i], i=36..47)

BUY  iff Q6 >= 5.35 and mom12 > +1e-12
SELL iff Q6 >= 5.35 and mom12 < -1e-12
FLAT otherwise
```

Require positive finite closes; finite returns, mean, centered values,
products, correlations, statistic, and momentum; and `den>1e-18`. Squared
autocorrelations deliberately make the gate sign-agnostic: both positive and
negative serial-dependence structures can qualify, while the independently
sourced twelve-month return supplies trade direction. A nonqualifying gate,
neutral direction, or invalid arithmetic consumes the month flat. Neither
the statistic nor momentum magnitude changes risk.

The `5.35` boundary is the predeclared two-decimal approximation to the
chi-square distribution's six-degree-of-freedom median
`5.348120627447121`. It is used as a state-frequency divider, not as a
significance test, p-value, or source claim. A fixed-seed market-free check
was completed before any WTI observation or backtest was examined.

## Event, Risk, And Lifecycle Contract

1. Persist normalized broker `yyyymm` before history, signal, news, spread,
   quote, ATR, sizing, margin, or order checks. Never retry a consumed month.
2. Use the latest D1 close from each immediately prior consecutive broker
   month. Require strict timestamp chronology and a newest endpoint no more
   than ten calendar days stale.
3. Open at most one WTI position under `RISK_FIXED=1000`, `RISK_PERCENT=0`,
   and `PORTFOLIO_WEIGHT=1`, sized against a frozen
   `3.5*ATR(20,D1)` broker hard stop. Attach no target.
4. Cap entry spread at 1,500 points. Both news axes, legacy news, Friday
   close, and stress rejection are OFF.
5. Close at the next genuine broker-month transition or after forty elapsed
   calendar days. Repair duplicate, wrong-symbol, wrong-side, or stopless
   owned exposure immediately.

Runtime uses registered MT5 D1 prices, timestamps, ATR, quotes, symbol
metadata, position/deal history, and terminal-global state only. No futures
curve, inventory feed, external file/API, optimizer output, portfolio state,
randomness, trained output, scale-in, grid, martingale, or pyramid is allowed.

## Market-Free Cadence Prior

The fixed-seed receipt
`artifacts/qm5_wti_ljungbox_tr_null_density_20260902.json` applies the exact
statistic to 200,000 independent 48-observation standard-normal paths. At the
rounded `Q6>=5.35` boundary, 50.1025% qualify, split into 24.9575% positive
and 25.1450% negative twelve-observation sums with no ties. This corresponds
to `6.0123` theoretical qualifying clocks per twelve months.

This is a market-free cadence sanity check, not WTI evidence, a calibrated
test size, performance, independence across rolling months, or a claim about
the true monthly state frequency. The gate was locked only to leave a
plausible path to the unchanged activity floor before any WTI observation was
examined. Q02 owns actual per-year activity and economics.

## Non-Duplicate Boundary

The corrected-root fail-closed checker scanned 4,798 EA identities, 1,427
card files, and 45 Strategy Wiki nodes without an exact or fuzzy match.
Receipt: `artifacts/qm5_wti_ljungbox_tr_preallocation_dedup_20260902.json`,
SHA-256
`C521D0D0F30869B1CD4F8F3B07DC8906B1D6B2EC472F420AE35BC61B36DF0D49`.

The nearest WTI monthly systems remain mechanically distinct:

- `QM5_20256_wti-vr6-mom` uses a signed linear combination of monthly
  autocorrelations embedded in a variance ratio. This gate sums six
  finite-sample-weighted squared autocorrelations, so lag signs cannot cancel.
- `QM5_41310_wti-mvnratio-tr` uses one raw squared successive-difference
  ratio. It is dominated by lag-one path variation and has no six-lag
  portmanteau aggregation.
- `QM5_41170_wti-bartels-trend` is rank based; this statistic preserves raw
  return magnitudes and aggregates ordinary autocorrelation across six lags.
- `QM5_41308`, `QM5_41309`, `QM5_41311`, and `QM5_41312` use ordinal entropy,
  sign-word LZ76 parsing, sample entropy, and DFT spectral entropy. None uses
  the Ljung-Box statistic. Pure trend, calendar, event, channel, variance,
  distribution, and relative-value systems use different state objects.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day XNG
  oscillator pullback, a different carrier, horizon, directionality, and
  mechanic.

Verdict:
`CLEAN_WTI_MONTHLY_48_RETURN_LJUNG_BOX_Q6_GE5P35_GATED_12M_CONTINUATION`.

## Reputable-Source Criteria

- R1 `PASS_WITH_SYNTHESIS_BOUNDARY`: named authors and peer-reviewed method
  and trading papers, DOI lineage, a complete open-access method read, and an
  existing governed complete WTI trading-paper read. The conjunction is
  explicitly new synthesis.
- R2 `PASS`: month clock, endpoints, return sample, demeaning, denominator,
  six autocorrelations, finite-sample weights, boundary, direction, attempt,
  risk, stop, spread, and lifecycle are locked.
- R3 `PASS_WITH_CONTINUOUS_CFD_BASIS_RISK`: registered `XTIUSD.DWX` D1 and
  native MT5 state supply every runtime input.
- R4 `PASS`: bounded deterministic arithmetic and native framework state;
  no trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Kill And Safety Boundary

Retire at zero completed positions, below five completed positions in any
full scored post-warm-up year, on nonpositive governed economics, or on any
endpoint, return, demeaning, autocorrelation, weight, statistic, boundary,
direction, attempt, risk, stop, or lifecycle defect. Do not rescue failure by
changing sample, lag count, weights, boundary, direction, carrier, stop, hold,
spread, or retry policy.

This source authorizes one branch-only non-live card/build, strict Q01, and
one paced Q02 enqueue under the current OWNER mission. It authorizes no manual
backtest; live/demo/shadow/stress/optimization preset; `T_Live` or AutoTrading
action; deploy/T_Live manifest; portfolio-gate edit; portfolio admission;
correlation waiver; or manual terminal control.
