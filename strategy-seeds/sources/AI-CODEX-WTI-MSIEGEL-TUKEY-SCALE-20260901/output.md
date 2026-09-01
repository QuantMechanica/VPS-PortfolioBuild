# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first executable tick of each normalized
broker month, reconstruct seventeen consecutive completed broker-month closes
and form sixteen adjacent log returns in fixed older/recent blocks of eight.
Reject any exact pooled return tie.

Sort the pooled returns and assign Siegel-Tukey ranks by alternating between
the low and high extremes. In ascending-return order the locked score path is
`1,4,5,8,9,12,13,16,15,14,11,10,7,6,3,2`. Sum the scores occupied by the
recent labels and enumerate all 12,870 eight-label assignments. Qualify a
recent dispersion state only at score at most 68 and inclusive lower-tail
count at most 6,698, then continue the sign of the recent eight-return sum for
one broker month. This exact half-support boundary is a disclosed pre-result
activity choice, not a conventional significance claim.

Consume the month before fallible entry gates. Use one position, one frozen
`3.5*ATR(20,D1)` hard stop, a 1,500-point spread ceiling,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Exit on the
next normalized broker month with forty-calendar-day stale repair.

This is a pre-result hypothesis. Siegel and Tukey, complete NIST method
documentation, and Moskowitz, Ooi, and Pedersen support the alternating-rank
arithmetic, WTI carrier, and broad own-return continuation family only. They
do not report this conjunction, half-support gate, activity, profitability,
CFD equivalence, or decorrelation.
