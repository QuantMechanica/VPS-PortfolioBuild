# QM5_41353 — WTI Monthly ADF–Phillips-Perron Agreement Trend

**EA ID:** QM5_41353

Strategy `AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905_S01`; carrier
`XTIUSD.DWX`; D1; slot 0; magic `413530000`.

## 1. Strategy Logic

At the first tradable D1 bar of a broker month, consume the month before every
fallible gate. Reconstruct 60 consecutive completed month-end closes and use
their natural-log levels, excluding the current month.

The first gate fits a lag-one intercept-only ADF regression over 58 changes,
with 55 residual degrees of freedom, and requires `ADF_t >= -2.594`. The second
fits a level AR(1) over 59 observations, with 57 residual degrees of freedom,
then applies the Phillips-Perron Z-tau correction from eleven Bartlett-weighted
residual autocovariances. It requires `PP_Z_tau >= -2.594`. Both boundaries are
inclusive and both gates must pass.

Direction is the sign of `x[59]-x[47]`: buy above `+1e-12`, sell below
`-1e-12`, otherwise flat. ADF-pass/PP-fail and ADF-fail/PP-pass both abstain.

## 2. Parameters

- 60 levels; ADF 58 observations/dof 55; PP 59 observations/dof 57.
- ADF determinant relative floor `1e-12`; shared energy floor `1e-18`.
- PP Bartlett/Newey-West covariance lags 11.
- History scan 1,800 D1 bars; endpoint freshness 10 days; grace 180 minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, spread cap 1,500 points.
- No retry, scaling, trail, news gate, Friday flatten, or stress rejection.
- Exit next broker month; 40-day defensive stale repair.

## 3. Symbol Universe

Only the registered native commodity carrier `XTIUSD.DWX`; no proxy or
fallback.

## 4. Timeframe

D1 host and execution timeframe. Decisions occur once per broker month from
completed D1-derived monthly endpoints.

## 5. Expected Behaviour

Fail closed on incomplete endpoints, invalid prices/arithmetic, singular
regression, nonpositive HAC variance, foreign exposure, malformed state, or
invalid execution inputs. Initialization runs deterministic agreement,
disagreement, mean-reversion, and degenerate fixtures. Q02 retires below five
completed trades in any full post-warm-up year or on nonpositive economics.

## 6. Source Citation

Approved composite `AI-CODEX-WTI-ADF-PP-AGREE-TREND-20260905`, grounded in
Chan (2013), Phillips and Perron (1988), *Biometrika* 75(2), DOI
`10.1093/biomet/75.2.335`, and Moskowitz, Ooi, and Pedersen (2012), *JFE*
104(2), DOI `10.1016/j.jfineco.2011.11.003`. No source validates the exact
conjunction or CFD transport.

## 7. Risk Model

The sole backtest mode is fixed USD 1,000, percent risk zero, weight one.
Continuous-CFD roll/basis/financing, gaps, small-sample diagnostic size, and
portfolio overlap remain risks. Q09 alone determines realized correlation.

No live use, portfolio admission, `T_Live`, terminal control, or AutoTrading
is authorized.

## Revision

2026-09-05: governed Q01 implementation; Q02 pending.
