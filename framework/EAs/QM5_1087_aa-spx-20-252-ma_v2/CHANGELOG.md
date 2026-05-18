# QM5_1087 aa-spx-20-252-ma v2

## 2026-05-18

- Rebuilt as a new `_v2` EA; v1 was not modified.
- Source diff: Alpha Architect specifies a daily S&P 500 risk switch: hold risk exposure when the 20-day moving average is above the 252-day moving average, otherwise hold cash. The v2 keeps that daily close rule and preserves bootstrap behavior: if the first eligible bar is already risk-on and the EA is flat, it opens long without waiting for a fresh crossover.
- Implementation diff: v2 defaults to magic slot `100` and disables the Friday close overlay because the source rule is daily risk-on/risk-off rather than intraday/weekend liquidation.
- Risk: both `RISK_FIXED` and `RISK_PERCENT` inputs remain explicit; default is fixed risk 1000 and percent risk 0.
- Source checked: https://alphaarchitect.com/a-simulation-study-on-simple-moving-average-rules/
