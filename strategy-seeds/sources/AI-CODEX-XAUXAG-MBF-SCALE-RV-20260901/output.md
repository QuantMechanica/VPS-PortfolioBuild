# Bounded source output

Select exact `XAUUSD.DWX` and `XAGUSD.DWX` D1. On the first executable tick of
each normalized broker month, reconstruct thirteen consecutive synchronized
completed broker-month endpoints. Form twelve adjacent changes of
`ln(XAU)-ln(XAG)`, with fixed older and recent blocks of six.

For each block, center its six changes on the even-sample median and form the
six absolute deviations. The state qualifies only when the recent mean
absolute deviation is strictly greater than the older value and the exact
Brown-Forsythe/median-centered Levene statistic is finite. Fade the change in
block medians: sell XAU/buy XAG when the recent median is higher; buy XAU/sell
XAG when it is lower. A tied median, non-expanding recent dispersion, or
degenerate within-group denominator consumes the month flat. The statistic is
diagnostic and is not compared with an F critical value or called a p-value.

Consume the month before fallible entry gates. Hold one atomic, opposite-side,
equal-target-notional package to the next normalized month, with forty-day
stale repair, frozen per-leg `3.5*ATR(20,D1)` hard stops, 1,500/500-point
spread ceilings, aggregate `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`.

This is a pre-result hypothesis. Brown and Forsythe, NIST, Schweikert, CME,
and SciPy supply method or carrier evidence, not this monthly trading rule,
its profitability, neutrality, activity, or decorrelation.

