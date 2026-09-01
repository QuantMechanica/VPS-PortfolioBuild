# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first executable tick of each normalized
broker month, reconstruct fifty-one completed D1 closes and form fifty
adjacent log returns in fixed older/recent blocks of twenty-five. Reject any
exact pooled return tie.

Rank the pooled returns ascending. For the recent block, compute the Wilcoxon
rank sum `W` and Ansari-Bradley symmetric end-rank score `A`. Form the
classical Lepage statistic
`L=(W-637.5)^2/2656.25+(A-325)^2/(32500/49)`. Qualify a joint location-scale
shift at `L>=1.3862943611198906`, the asymptotic chi-square-two median, and
continue the sign of the recent twenty-five-return sum for one broker month.
The median gate is a disclosed pre-result activity choice, not a conventional
significance claim.

Consume the month before fallible entry gates. Use one position, one frozen
`3.5*ATR(20,D1)` hard stop, a 1,500-point spread ceiling,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Exit on the
next normalized broker month with forty-calendar-day stale repair.

This is a pre-result hypothesis. Lepage, the complete author preprint, the
complete CRAN source, and Moskowitz, Ooi, and Pedersen support the joint-rank
arithmetic, WTI carrier, and broad own-return continuation family only. They
do not report this conjunction, the median gate, activity, profitability,
CFD equivalence, or decorrelation.
