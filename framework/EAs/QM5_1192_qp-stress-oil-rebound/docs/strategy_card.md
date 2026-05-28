---
ea_id: QM5_1192
slug: qp-stress-oil-rebound
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
g0_status: APPROVED
pipeline_phase: G0
last_updated: 2026-05-18
---

# Quantpedia Cross-Asset Stress Oil Rebound

## Quelle
- Source: Quantpedia Encyclopedia - Short-Term Correlated Stress Reversal Trading
- URL: quantpedia.com/short-term-correlated-stress-reversal-trading/
- Citation date: 2026-05-17 research extraction.
- Named source author: Cyril Dujava, Quantpedia.

## Mechanik

### Entry
On each completed D1 bar:
1. Compute close-to-close returns for `SP500.DWX` and `XAUUSD.DWX`.
2. If both returns are below `0.0%`, mark a correlated equity/gold stress day.
3. At that D1 close, open LONG the approved oil proxy (`XTIUSD.DWX` preferred; `XBRUSD.DWX` fallback).
4. Hold one oil rebound position per magic number.

### Exit
- Close the oil position at the next D1 close.
- Safety exit after 2 trading days if the next close is unavailable.

### Stop Loss
- Initial stop: 1.5x ATR(20) D1 on the oil proxy.
- No trailing stop; one-day holding period is the main exit.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Requires confirmed oil CFD symbol and synchronized D1 closes across `SP500.DWX`, `XAUUSD.DWX`, and the oil proxy.
- P3 may test stricter stress thresholds (`-0.5%`, `-1.0%`) but P1 default is the fixed negative-return test.

## R3 - T6 Live-Promotion-Caveat
`SP500.DWX` is not broker-routable. If the EA passes P0-P9 using `SP500.DWX` as a required signal leg, T6 deploy requires a parallel-validation using `NDX.DWX` or `WS30.DWX` as the equity-stress proxy before AutoTrading enable.
