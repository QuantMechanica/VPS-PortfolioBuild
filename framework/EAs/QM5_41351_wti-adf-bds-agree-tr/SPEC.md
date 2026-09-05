# QM5_41351 — WTI Monthly ADF and BDS Agreement Trend

**EA ID:** QM5_41351  
**Carrier/timeframe:** `XTIUSD.DWX` D1  
**Magic:** `413510000`

## 1. Strategy Logic

On the first tradable D1 bar of each broker month, consume the month before
any fallible gate and reconstruct 61 consecutive completed broker-month-end
closes. A lag-one intercept ADF regression on the newest 60 log levels must
have `t_gamma >= -2.594`. A dimension-two BDS statistic on the newest 48
monthly returns must have `abs(BDS2) >= 0.6744897501960817`. Only when both
gates qualify does the EA follow the newest 12-month return sign for one
broker month.

## 2. Parameters And Risk

- ADF: 58 rows, residual dof 55, energy floor `1e-18`, determinant relative
  floor `1e-12`, inclusive threshold `-2.594`.
- BDS: newest 48 returns, sample `ddof=1`, `epsilon=1.5*sd`, strict distance,
  embedding dimension two, full and conditioned pair sums, inclusive absolute
  threshold `0.6744897501960817`.
- History 1,800 D1 bars; grace 180 minutes; endpoint staleness 10 days.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling.
- Next-month exit; 40-day stale repair; news, Friday close, and stress off.

## 3. Symbol Universe

The only host, logical, and traded symbol is registered native
`XTIUSD.DWX`, slot zero. No proxy, basket, or fallback carrier is allowed.

## 4. Timeframe

Attach and test only on D1. Decisions occur once per genuine broker month
from completed D1 bars; no current-month close enters either diagnostic.

## 5. Expected Behaviour

Fail closed on incomplete/nonconsecutive endpoints, current-month leakage,
nonpositive closes, nonfinite or degenerate formula paths, either rejected
gate, neutral momentum, foreign exposure, malformed owned state, or invalid
quote/ATR/sizing/margin/stop. A consumed month is never retried. No intramonth
diagnostic exit, resizing, scale-in, pyramid, grid, or martingale is allowed.

## 6. Source Citation

The approved source is
`AI-CODEX-WTI-ADF-BDS-AGREE-TREND-20260905`, composed from complete governed
Chan/Wiley ADF, peer-reviewed Broock-Scheinkman-Dechert-LeBaron BDS with a
pinned statsmodels implementation, and Moskowitz-Ooi-Pedersen/JFE WTI
continuation records. No parent validates this conjunction or CFD transport.
The BDS delay-vector pair geometry differs from every other ADF agreement
sibling; parent-only EAs omit one required gate.

## 7. Risk Model

The sole backtest mode is fixed USD 1,000 risk, percent risk zero, and weight
one. The frozen broker stop is `3.5*ATR(20,D1)`. Continuous-CFD roll,
basis/financing, gaps, shared WTI direction, overlapping samples, and
finite-sample diagnostic size are material. Signal magnitude never changes
size.

## Validation And Safety

Reference fixtures cover exact ADF and BDS arithmetic, both directions, both
disagreement paths, degeneracy, card mirror, magic, and the fixed-risk set
contract. Q02 retires below five completed trades in any full scored
post-warm-up year or on nonpositive economics/contract failure. Only Q09 can
establish portfolio decorrelation.

This build does not authorize live use, portfolio admission, portfolio-gate
changes, deployment/live manifests, `T_Live`, terminal control, or
AutoTrading.

## Revision

2026-09-05: governed Q01 implementation from the approved card; Q02 pending.
