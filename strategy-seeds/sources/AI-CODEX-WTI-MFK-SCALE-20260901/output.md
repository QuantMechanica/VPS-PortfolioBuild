# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first executable tick of each normalized
broker month, reconstruct thirteen consecutive completed broker-month end
closes and form twelve adjacent log returns in fixed older/recent blocks of
six.

Center each block on its own even median and pool the twelve absolute
deviations. Assign deterministic pooled midranks and transform each rank `R`
to the Fligner-Killeen normal score
`Phi^-1(0.5 + R/(2*(12+1)))`. Compute the exact two-group Fligner-Killeen
statistic as an arithmetic guard. Qualify only when the recent block's mean
normal score is strictly above the older block's score, then continue the
sign of the recent six-month cumulative return for one broker month. A tied
score mean, neutral recent return, degenerate score variance, malformed
history, or nonfinite value consumes the month flat. No chi-square critical
value or p-value enters the rule.

Consume the month before fallible entry gates. Use one position, one frozen
`3.5*ATR(20,D1)` hard stop, a 1,500-point spread ceiling, aggregate
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Exit on the
next normalized broker month with forty-calendar-day stale repair.

This is a pre-result hypothesis. Fligner and Killeen, SciPy, and Moskowitz,
Ooi, and Pedersen support the scale arithmetic, WTI carrier, and general
monthly own-return continuation family only. They do not report this trading
conjunction, its activity, profitability, CFD equivalence, or decorrelation.

