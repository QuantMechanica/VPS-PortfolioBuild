# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first executable tick of each normalized
broker month, reconstruct fifty-one completed D1 closes and form fifty
adjacent log returns in fixed older/recent blocks of twenty-five.

Apply the Epps-Singleton empirical-characteristic-function two-sample
statistic with the source-default points `(0.4, 0.8)` divided by the pooled
semi-interquartile range. Use the four features
`[cos(t1*r), cos(t2*r), sin(t1*r), sin(t2*r)]`, biased within-block
covariances, the source-defined pooled covariance, and a fail-closed full-rank
4x4 inverse. Qualify a distribution-shift state when the finite statistic is
at least `3.356693980033321`, the chi-square-four median. Continue the sign of
the recent twenty-five-return sum for one broker month. The median gate is a
disclosed pre-result activity choice, not a conventional significance claim.

Consume the month before fallible entry gates. Use one position, one frozen
`3.5*ATR(20,D1)` hard stop, a 1,500-point spread ceiling,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Exit on the
next normalized broker month with forty-calendar-day stale repair.

This is a pre-result hypothesis. Epps and Singleton, pinned official SciPy
evidence, and Moskowitz, Ooi, and Pedersen support the distribution-comparison
arithmetic, WTI carrier, and general own-return continuation family only.
They do not report this conjunction, the median gate, its activity,
profitability, CFD equivalence, or decorrelation.

