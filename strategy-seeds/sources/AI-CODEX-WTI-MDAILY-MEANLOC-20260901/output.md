# Bounded source output

Select exact `XTIUSD.DWX` D1. On the first tradable bar of each normalized
broker month, reconstruct every D1 close in the immediately completed broker
month. Require 17 through 23 closes and one older bar proving the boundary.
Let `mean_close` be their arithmetic mean and `final_close` the newest close.

```text
location = final_close / mean_close - 1
BUY  when location >  1e-12
SELL when location < -1e-12
FLAT otherwise
```

Consume the month before fallible entry gates. Hold at most one position to
the next normalized month, with a forty-day stale repair, frozen
`3.5*ATR(20,D1)` hard stop, no target, 1,500-point spread ceiling,
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

This is a pre-result hypothesis. The within-month mean-location statistic is
a transparent QM interpretation of monthly WTI continuation evidence, not a
published trading rule or a profitability/decorrelation claim.

