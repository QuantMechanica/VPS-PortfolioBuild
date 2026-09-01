# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first executable tick of each normalized
broker month, reconstruct thirteen consecutive completed broker-month end
closes and form twelve adjacent log returns in fixed older/recent blocks of
six.

Pool the twelve returns, require them to be unique under an anchored relative
`1e-12` tolerance, and assign deterministic average ranks 1..12. For the six
older observations compute Mood's squared-rank score
`M_old=sum((R-6.5)^2)`. Its fixed-null expectation is `71.5` and no-tie
variance is `364`, so `z=(M_old-71.5)/sqrt(364)`. Qualify recent scale
non-contraction when `M_old <= 71.5`; then continue the sign of the recent
six-month cumulative return for one broker month. Compute finite `z` as an
arithmetic guard only. No normal probability, p-value, optimizer, fitted
threshold, or statistic-magnitude sizing enters the rule.

Consume the month before fallible entry gates. Use one position, one frozen
`3.5*ATR(20,D1)` hard stop, a 1,500-point spread ceiling, aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Exit on the
next normalized broker month with forty-calendar-day stale repair.

This is a pre-result hypothesis. Mood, pinned official SciPy evidence, and
Moskowitz, Ooi, and Pedersen support the squared-rank scale arithmetic, WTI
carrier, and general monthly own-return continuation family only. They do not
report this conjunction, the inclusive non-contraction rule, its activity,
profitability, CFD equivalence, or decorrelation.

