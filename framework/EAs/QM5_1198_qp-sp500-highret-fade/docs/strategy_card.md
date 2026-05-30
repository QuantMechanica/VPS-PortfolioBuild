---
ea_id: QM5_1198
slug: qp-sp500-highret-fade
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia SP500 High Return Fade

Source: Quantpedia Automated Trading Edge Analysis, Daniela Hanicova, section "Trading Based on Significant Days".

## Entry
On each completed D1 bar for `SP500.DWX`, compute the daily close-to-close return and rank it against the previous 250 completed daily returns. If today's return is among the 25 highest returns in that window, open SHORT `SP500.DWX` at the next regular-session open. Do not enter if this magic already has an open position.

## Exit
Close after 1 trading day at the regular-session close. P3 may test 2-day and 3-day holding periods. Safety exit closes at the next available bar if the scheduled close is missed.

## Risk
Hard stop is `2.0x ATR(20) D1` from entry. Gap-risk kill closes if loss exceeds `2.5x` planned risk. Baseline uses `RISK_FIXED=1000`; live template uses `RISK_PERCENT=0.25`.

## Filters
Require at least 270 valid D1 bars. Skip if spread is greater than `3x` the 20-day median M30 spread.

## T6 Caveat
`SP500.DWX` is not broker-routable. T6 deploy requires parallel validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
