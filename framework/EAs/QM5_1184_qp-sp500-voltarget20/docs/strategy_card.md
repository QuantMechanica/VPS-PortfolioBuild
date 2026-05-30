---
ea_id: QM5_1184
slug: qp-sp500-voltarget20
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/volatility-management]]"
  - "[[concepts/market-timing]]"
indicators:
  - "[[indicators/realized-volatility]]"
  - "[[indicators/exposure-scaling]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-18
g0_approval_reasoning: "qp-sp500-voltarget20 Harvey et al. 2018 JPM SSRN 3175538 clamped vol-target [0.25,1.0] D1 rebalance R1-R4 PASS bounded worst-case not ML/adaptive"
---

# Quantpedia SP500 20-Day Volatility Targeting

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "The Impact of Volatility Targeting on Equities, Bonds, Commodities and Currencies"
- Named authors: Campbell Harvey, Edward Hoyle, Sandy Rattray, Matthew Sargaison, Dan Taylor, and Otto Van Hemert.
- Year-tagged citation: Harvey, Hoyle, Rattray, Sargaison, Taylor, Van Hemert (2018). "The Impact of Volatility Targeting." Journal of Portfolio Management. SSRN 3175538. Quantpedia review, 2024 accessed.

## Mechanik

### Entry
On each completed D1 bar for `SP500.DWX`:
1. Compute realized volatility using exponentially weighted daily returns with 20-day half-life.
2. Compute target exposure multiplier: `target_annual_vol / realized_annual_vol`, with `target_annual_vol = 10%`.
3. Clamp multiplier to `[0.25, 1.00]` to avoid leverage and preserve bounded worst-case exposure.
4. If multiplier is at least 0.25 and no position exists, open LONG `SP500.DWX`.
5. If a position exists, rebalance only when desired risk differs from current risk by at least 25%.

### Exit
- Close if realized annualized volatility exceeds 40% for three consecutive completed D1 bars.
- Otherwise remain long with clamped exposure until the next rebalance.

### Stop Loss
- Initial stop: 3.0x ATR(20) on D1.
- Trailing stop: 3.0x ATR(20), updated once per completed D1 bar.

### Position Sizing
- P2 baseline: base `RISK_FIXED = 1000` USD, multiplied by the clamped volatility-target multiplier.
- Live: base `RISK_PERCENT = 0.25`, multiplied by the clamped volatility-target multiplier.

### Zusaetzliche Filter
- This card intentionally uses volatility as deterministic exposure management, not parameter optimization.
- No leverage above normal baseline risk is allowed.
- Optional P3 variants: 8%, 10%, and 12% annual target volatility; 10/20/60-day half-life.

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: `SP500.DWX` is not broker-routable. If the EA passes P0-P9 on `SP500.DWX` only, T6 deploy requires a parallel-validation on `NDX.DWX` or `WS30.DWX` before AutoTrading enable.
