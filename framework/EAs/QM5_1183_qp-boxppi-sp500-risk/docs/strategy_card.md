---
ea_id: QM5_1183
slug: qp-boxppi-sp500-risk
type: strategy
source_id: 7ede58dd-d184-5099-9d48-7a65de230853
sources:
  - "[[sources/quantpedia-encyclopedia]]"
concepts:
  - "[[concepts/macro-timing]]"
  - "[[concepts/market-timing]]"
indicators:
  - "[[indicators/producer-price-index]]"
  - "[[indicators/moving-average-filter]]"
g0_status: APPROVED
r1_track_record: UNKNOWN
r2_mechanical: UNKNOWN
r3_data_available: UNKNOWN
r4_ml_forbidden: UNKNOWN
pipeline_phase: G0
last_updated: 2026-05-17
g0_approval_reasoning: "R1 URL+author cited; R2 deterministic monthly lagged PPI SMA long/cash switch; R3 SP500.DWX backtest route with T6 caveat; R4 fixed rules no ML/grid/martingale."
---

# Quantpedia Box-PPI SP500 Risk Switch

## Quelle
- Source: [[sources/quantpedia-encyclopedia]] - Quantpedia "Alternative Market Signals: Investing with the Box Manufacturing Index"
- Retrieved 2026-05-17, URL: quantpedia.com/alternative-market-signals-investing-with-the-box-manufacturing-index/
- Named author: David Belobrad, Junior Quant Analyst, Quantpedia.
- Location: MA models / "SPY strategy" section.

## Mechanik

### Entry
Monthly, after the corrugated-box PPI value is available with a one-month data lag:
1. Load `PCU3222113222110` (Producer Price Index by Industry: Corrugated and Solid Fiber Box Manufacturing) from a checked-in deterministic CSV.
2. Compute the 6-month SMA of the lagged monthly PPI series.
3. If current lagged PPI is below its 6-month SMA, open LONG `SP500.DWX` at the next D1 open.
4. If already long, keep the position while the condition remains true.

### Exit
- Close `SP500.DWX` when current lagged PPI is greater than or equal to its 6-month SMA.
- Re-evaluate monthly only; no intramonth signal changes.

### Stop Loss
- Initial stop: 2.5x ATR(20) on D1.
- Monthly time stop is not used; signal controls exposure.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000` USD.
- Live: `RISK_PERCENT = 0.25`.

### Zusaetzliche Filter
- Source found the broad SPY version weaker than sector switches; this card keeps the broad SP500 route because sector ETFs are not confirmed in DWX.
- Data lag must be enforced: no trading on unreleased or revised future PPI data.
- Optional P3 variants: 3-month and 9-month PPI SMA.

## Concepts
- [[concepts/macro-timing]] - primary
- [[concepts/market-timing]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Track Record | UNKNOWN | Quantpedia article URL is verifiable and names David Belobrad. |
| R2 Mechanical | UNKNOWN | Monthly PPI CSV, SMA(6), long/cash state, and monthly rebalance are deterministic. |
| R3 Data Available | UNKNOWN | Trade leg uses SP500.DWX backtest route; PPI must be supplied as a deterministic external CSV. |
| R4 ML Forbidden | UNKNOWN | Fixed moving-average rule only; no ML, adaptive parameters, grid, or martingale. |

## R3 - T6 Live-Promotion-Caveat
Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
