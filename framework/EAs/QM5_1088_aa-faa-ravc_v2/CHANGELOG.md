# QM5_1088 aa-faa-ravc v2

## 2026-05-18

- Rebuilt as a new `_v2` EA; v1 was not modified.
- Source diff: Alpha Architect FAA RAVC ranks seven assets monthly using 4-month relative momentum, 4-month volatility, and 4-month average correlation, with weights 100%, 50%, and 50%, then invests in the top three assets that pass absolute momentum.
- Implementation diff: v2 evaluates the monthly rebalance from D1 bars instead of H1 bars, keeping the source rule aligned with daily/monthly total-return inputs.
- Implementation diff: v2 uses magic slots `100` through `106` for the seven canonical proxy legs so each symbol has an independent resolver entry.
- Risk: both `RISK_FIXED` and `RISK_PERCENT` inputs remain explicit; default is fixed risk 1000 and percent risk 0, distributed through `PORTFOLIO_WEIGHT`.
- Source checked: https://alphaarchitect.com/flexible-asset-allocation-dethroning-moving-average-rules/
