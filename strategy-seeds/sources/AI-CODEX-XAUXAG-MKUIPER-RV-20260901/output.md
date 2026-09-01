# Bounded source output

Select exact `XAUUSD.DWX` and `XAGUSD.DWX` D1. On the first executable tick of
each normalized broker month, reconstruct thirteen consecutive completed
broker-month endpoints whose timestamps match across both legs. Form twelve
adjacent changes of `ln(XAU)-ln(XAG)`, with the older six and recent six fixed.
Require every change pairwise distinct.

At every pooled rank compute the recent-minus-old empirical-CDF gap. The
two-sample Kuiper distance is the largest positive gap plus the largest
negative gap. Enumerate all `C(12,6)=924` recent-label assignments. Qualify
only when observed `V>=0.5`, the inclusive greater-tail count is at most 798,
and the recent rank sum differs from neutral 39. Fade the recent distribution:
sell XAU/buy XAG above 39; buy XAU/sell XAG below 39.

Consume the month before fallible entry gates. Hold one atomic, opposite-side,
equal-target-notional package to the next normalized month, with forty-day
stale repair, frozen per-leg `3.5*ATR(20,D1)` hard stops, 1,500/500-point
spread ceilings, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This is a pre-result hypothesis. Kuiper supplies a distribution-distance
statistic, not this monthly gold/silver trading rule, its activity boundary,
profitability, neutrality, or decorrelation.
