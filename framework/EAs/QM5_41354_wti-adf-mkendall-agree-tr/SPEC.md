# QM5_41354 — WTI Monthly ADF–Mann-Kendall Agreement Trend

**EA ID:** QM5_41354  
**Strategy:** `AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905_S01`  
**Carrier:** `XTIUSD.DWX`, D1, slot 0, magic `413540000`

## 1. Strategy Logic

At the first tradable D1 bar of a broker month, consume the month before every
fallible gate. Reconstruct 60 consecutive completed month-end closes and use
their natural-log levels, excluding the current month.

The state gate fits a lag-one intercept-only ADF regression over 58 changes,
with 55 residual degrees of freedom, and requires `ADF_t >= -2.594`. The
direction gate compares every older/newer pair among the newest 13 completed
month ends. Exact ties fail closed. It requires `abs(S) >= 28`; positive score
buys and negative score sells. Both functions must pass.

## 2. Parameters

- 60 levels; ADF 58 observations/dof 55; determinant floor `1e-12`.
- Newest 13 endpoints; all 78 pairs; exact-tie rejection; score boundary 28.
- History scan 1,800 D1 bars; endpoint freshness 10 days; grace 180 minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, spread cap 1,500 points.
- No retry, scaling, trail, news gate, Friday flatten, or stress rejection.
- Exit next broker month; 40-day defensive stale repair.

## 3. Symbol Universe

The only host, logical, and traded symbol is registered native
`XTIUSD.DWX`, slot zero. No proxy, basket, synthetic spread, or fallback
carrier is allowed.

## 4. Timeframe

Attach and test only on D1. Decisions occur once per genuine broker month
from completed D1 bars; no current-month close enters either diagnostic.

## 5. Expected Behaviour

Fail closed on incomplete or nonconsecutive endpoints, current-month leakage,
nonpositive closes, exact endpoint ties, nonfinite or degenerate arithmetic,
either rejected gate, foreign exposure, malformed owned state, or invalid
quote, ATR, sizing, margin, or stop state. A consumed month is never retried.
No intramonth diagnostic exit, resizing, scale-in, pyramid, grid, or martingale
is allowed.

## 6. Source Citation

Approved composite
`AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905`, grounded in Chan (2013),
Wiley, and Moskowitz, Ooi, and Pedersen (2012), *JFE* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. Neither source validates the conjunction or
continuous-CFD transport.

## 7. Risk Model

The sole Q02 baseline uses fixed USD 1,000 risk, percent risk zero, and weight
one. The frozen broker stop is `3.5*ATR(20,D1)`. WTI gap,
roll/basis/financing, sparse qualification, shared WTI direction, overlapping
samples, and finite-sample diagnostic size are material. Signal magnitude
never changes size. Q09 alone determines realized portfolio correlation.

## Validation And Safety

Reference fixtures cover exact ADF and Mann-Kendall arithmetic, both
directions, both inclusive boundaries, exact-tie rejection, the card mirror,
magic, and fixed-risk set contract. Q02 retires below five completed trades in
any full scored post-warm-up year or on nonpositive economics or contract
failure.

No live use, portfolio admission, portfolio-gate change, `T_Live`, terminal
control, AutoTrading, or deploy/live-manifest change is authorized.

## Revision

2026-09-05: governed Q01 implementation from the approved card; Q02 pending.
