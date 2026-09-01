# Governed synthesis output

Use a monthly WTI return-location regime-shift continuation rule based on the
two-sample 20%-trimmed Yuen statistic.

- Reconstruct 21 consecutive completed `XTIUSD.DWX` broker-month end closes.
- Form 20 adjacent chronological log returns.
- Fix the oldest ten returns as `old` and newest ten as `recent`.
- In each block, sort, remove the two observations at each tail, and average
  the middle six values.
- For scale, Winsorize each ten-value block by replacing its two low values
  with order statistic three and its two high values with order statistic
  eight. Compute the Winsorized variance using divisor five, matching the
  effective trimmed sample size `h=6`.
- Compute `t=(trimmed_mean_recent-trimmed_mean_old) /
  sqrt(wvar_old/6+wvar_recent/6)`.
- Buy at `t>=0.75`, sell at `t<=-0.75`, and otherwise remain flat.
- Consume one attempt per broker month, risk one fixed USD budget behind a
  frozen `3.5*ATR(20,D1)` stop, and exit at the next broker month or after
  forty calendar days.

The `0.75` boundary is a pre-result activity boundary, not a significance
critical value. No p-value, degrees of freedom, fitted split, optimization,
external feed, banned signal indicator, trained model, scale-in, grid,
martingale, or live action is authorized.
