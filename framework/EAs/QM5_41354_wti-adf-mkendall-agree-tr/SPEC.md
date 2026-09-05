# QM5_41354 — WTI Monthly ADF–Mann-Kendall Agreement Trend

**EA ID:** QM5_41354  
**Strategy:** `AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905_S01`  
**Carrier:** `XTIUSD.DWX`, D1, slot 0, magic `413540000`

## Strategy logic

At the first tradable D1 bar of a broker month, consume the month before every
fallible gate. Reconstruct 60 consecutive completed month-end closes and use
their natural-log levels, excluding the current month.

The state gate fits a lag-one intercept-only ADF regression over 58 changes,
with 55 residual degrees of freedom, and requires `ADF_t >= -2.594`. The
direction gate compares every older/newer pair among the newest 13 completed
month ends. Exact ties fail closed. It requires `abs(S) >= 28`; positive score
buys and negative score sells. Both functions must pass.

## Parameters and lifecycle

- 60 levels; ADF 58 observations/dof 55; determinant floor `1e-12`.
- Newest 13 endpoints; all 78 pairs; exact-tie rejection; score boundary 28.
- History scan 1,800 D1 bars; endpoint freshness 10 days; grace 180 minutes.
- `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Frozen `3.5*ATR(20,D1)` hard stop, no target, spread cap 1,500 points.
- No retry, scaling, trail, news gate, Friday flatten, or stress rejection.
- Exit next broker month; 40-day defensive stale repair.

## Source and risk boundary

Approved composite
`AI-CODEX-WTI-ADF-MKENDALL-AGREE-TREND-20260905`, grounded in Chan (2013),
Wiley, and Moskowitz, Ooi, and Pedersen (2012), *JFE* 104(2), DOI
`10.1016/j.jfineco.2011.11.003`. Neither source validates the conjunction or
continuous-CFD transport. WTI gap, roll/basis/financing, sparse qualification,
and portfolio overlap remain risks. Q09 alone determines realized correlation.

No live use, portfolio admission, portfolio-gate change, `T_Live`, terminal
control, AutoTrading, or deploy/live-manifest change is authorized.
