---
ea_id: QM5_1200
slug: qp-sp500-max10-fade
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia SP500 10-Day Maximum Fade

## Quelle
- Source: Quantpedia encyclopedia, "Automated Trading Edge Analysis" (Hanicova, Quantpedia 2024).
- Named source author: Daniela Hanicova, Quant Analyst, Quantpedia (accessed 2026-05-17).
- Location: "Practical trading edge - Short-Term Strategies", subsection "10-Day Minimum / Maximum".

## Mechanik

### Entry
On each completed D1 bar for `SP500.DWX`:
1. Compute the rolling 10-day maximum of D1 closes including the current completed close.
2. If today's close is equal to the rolling 10-day maximum, open SHORT `SP500.DWX` at the next regular-session open.
3. Do not add if a position is already open.

### Exit
- Close after 1 trading day at the regular-session close.
- P3 may test holding until the first close below SMA(10), but P1 uses the fixed next-day exit to keep the card narrow.
- Safety exit: close at the next available bar if the scheduled close is missed.

### Stop Loss
- Hard stop: 2.0x ATR(20) D1 from entry.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Require 60 valid D1 closes before first signal.
- Spread filter: skip if spread is greater than 3x the 20-day median M30 spread.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires a parallel-validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
