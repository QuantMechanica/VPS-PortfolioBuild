# DXZ TOTAL_RISK review template

Generated: `2026-07-19T15:37:22Z`

Evidence window: `2026-07-20` through `2026-07-19`
Status: **HOLD**

This is an OWNER decision template. It cannot apply weights, edit presets, change
live settings, or authorize a risk increase.

## Evidence maturity

- Completed live sessions: **0**
- Minimum for a monthly proposal: **21**
- Full live-volatility saturation: **42**
- Attributed closed positions: **0**
- Blend-rule OOS verdict: **FAIL**
- Current TOTAL_RISK: **9.750000**
- Hard per-sleeve cap in every scenario: **1.000000**

## Book evidence (no forecast input)

| metric | live realised deals | sealed backtest at current weights |
|---|---:|---:|
| annualised daily vol | 0.000000% | 3.623198% |
| max drawdown | 0.000000% | 2.587490% |
| worst day | 0.000000% | -0.857306% |
| total net | 0.00 | 72231.63 |

Live closed-deal drawdown is not account-equity drawdown and cannot by itself
support a TOTAL_RISK increase.

## HOLD acknowledgement

This package is not eligible for approval and contains no proposed weights.
Record only acknowledgement, rejection, or a request for additional evidence;
no approval or deploy field is intentionally rendered.


No candidate above the current total is generated automatically. A later review
must attach book-level realised volatility/drawdown, scenario evidence, and a
written OWNER decision. Until then, deployment action is `NONE`.
