# QM5_41336 — WTI Monthly ADF-KPSS Agreement Trend

**EA ID:** QM5_41336

EA ID `QM5_41336`; strategy `AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904_S01`;
carrier `XTIUSD.DWX`; timeframe D1; slot 0; magic `413360000`.

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, consume the month before any
fallible gate. Reconstruct exactly 60 consecutive completed broker-month-end
closes, oldest to newest, excluding every current-month price. Let
`x[t] = ln(close[t])`.

The ADF path fits, for `t=2..59`:

```text
y[t] = x[t] - x[t-1]
z[t] = x[t-1]
w[t] = x[t-1] - x[t-2]
y[t] = alpha + gamma*z[t] + phi*w[t] + error[t]
```

It uses centered cross-products, 58 observations, three fitted coefficients,
`SSE/55`, `se_gamma=sqrt((SSE/55)*Sww/determinant)`, and
`ADF_t=gamma/se_gamma`. The ADF gate passes inclusively at `ADF_t >= -2.594`.

The independent KPSS path demeans the same 60 log levels, sums squared partial
sums as `eta`, and forms a long-run variance from lag 0 plus four Bartlett
weighted covariance lags with weights `1-lag/5`. It computes
`KPSS=eta/long_run_variance` and passes inclusively at `KPSS >= 0.347`.

The strategy may trade only when both gates pass. Direction is the sign of
`x[59]-x[47]`: buy above `+1e-12`, sell below `-1e-12`, otherwise stay flat.
The two disagreement fixtures are mandatory: ADF-pass/KPSS-fail and
ADF-fail/KPSS-pass both abstain.

## 2. Parameters

- 60 levels; ADF 58 observations and 55 residual degrees of freedom.
- ADF determinant relative floor `1e-12`; shared arithmetic and KPSS variance
  floors `1e-18`; KPSS covariance lags 4.
- D1 history scan 1800 bars; endpoint staleness 10 days; entry grace 180 minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- ATR(20) from the completed D1 bar, frozen `3.5*ATR` hard stop, no target.
- Spread ceiling 1500 points; no retry, scale-in, trail, news gate, Friday
  flatten, stress rejection, or discretionary intramonth exit.
- Exit on the first processed tick in a later normalized broker month; 40-day
  stale repair remains a defensive ceiling.

## 3. Symbol Universe

The only logical, host, and traded symbol is the registered native commodity
carrier `XTIUSD.DWX`. No proxy, basket, or fallback symbol is allowed.

## 4. Timeframe

The EA must be attached and tested on D1. Decisions occur once per broker month
from completed D1 bars; the 60 observations are completed monthly endpoints.

## 5. Expected Behaviour

The EA fails closed on incomplete/non-consecutive endpoints, nonpositive prices,
nonfinite arithmetic, singular regression, nonpositive long-run variance,
foreign carrier exposure, malformed owned state, invalid quote, ATR, sizing, or
stop. Initialization runs deterministic up, down, both disagreement, mean-
reverting, and degenerate reference paths.

Q02 must retire the unchanged baseline on zero trades, fewer than five completed
positions in any full post-warm-up year, nondeterminism, nonpositive governed
economics, or a contract defect.

## 6. Source Citation

The exact synthesis is the approved governed record
`AI-CODEX-WTI-ADF-KPSS-AGREE-TREND-20260904`. Supporting complete-read records
are Chan (2013) for the lag-one ADF construction, Kwiatkowski et al. (1992),
Journal of Econometrics 54, DOI `10.1016/0304-4076(92)90104-Y`, for KPSS, and
Moskowitz, Ooi, and Pedersen (2012), Journal of Financial Economics 104(2), DOI
`10.1016/j.jfineco.2011.11.003`, for monthly WTI continuation evidence. Those
sources do not validate this exact conjunction or its CFD transport.

## 7. Risk Model

The only backtest risk mode is fixed USD 1,000 with weight 1 and percent risk
zero. Continuous-CFD roll, basis, financing, gaps, small-sample instability,
and overlap remain material risks. Only Q09 may make a realized portfolio-
correlation determination.

This build does not authorize live use, portfolio admission, T_Live changes,
terminal control, or AutoTrading.

## Revision

2026-09-04: governed Q01 implementation from the approved card; Q02 pending.
