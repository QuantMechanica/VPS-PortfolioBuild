---
ea_id: QM5_10125
slug: psar-sma-stop
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/parabolic-sar]]"
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/trailing-stop]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 mechanical PSAR/SMA entry and 15pct trailing exit with plausible 8 trades/year/symbol; R3 portable to DWX CFDs with SP500 T6 caveat; R4 fixed non-ML one-position rules."
---

# PSAR Entry With Long-Term SMA Filter And 15% Trailing Stop

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/how-to-test-and-trade-a-strategy-with-the-psar-indicator/
- Author / institution: Raposa
- Date: 2022-06-29
- Location: sections "Build a Trading Algorithm with the PSAR", "Improving your Backtest with a Trend Filter"

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute Parabolic SAR using standard MT5 defaults initially: step 0.02, maximum 0.20.
- Compute a long-term SMA crossover filter. Source states the values should be long-term, greater than 150 days; initial deterministic port uses SMA(50) > SMA(200).
- Enter long when PSAR indicates an uptrend and SMA(50) > SMA(200).
- Optional symmetric short variant: enter short when PSAR indicates downtrend and SMA(50) < SMA(200).

### Exit
- Source replaces PSAR exit with a trailing stop to avoid cutting off long-term trends.
- Exit long when close falls 15% below the highest close since entry.
- Exit short, if enabled, when close rises 15% above the lowest close since entry.

### Stop Loss
- 15% close-based trailing stop.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- Source example uses volatility allocation with 252-day lookback and max risk fraction 0.3; leave as P3 variant, not baseline.

### Zusätzliche Filter
- Warmup: 252 daily bars for volatility-sizing variant, otherwise 200 daily bars.
- Trade only after both PSAR and SMA filter are valid.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/trend-filter]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa tutorial URL with author/institution and date. |
| R2 Mechanical | PASS | PSAR trend state, SMA filter, and 15% trailing stop are deterministic. |
| R3 Data Available | PASS | ETF/stock example ports to DWX index CFDs and FX/commodity CFDs. |
| R4 ML Forbidden | PASS | Fixed indicators and no adaptive/ML component. |

## R3
For S&P-style ETF examples, SP500.DWX is backtest-only. Live promotion T6 gate: if the EA passes P0-P9 on SP500.DWX only, T6 deploy requires parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source describes the filtered version as a "good looking strategy".
- Source says the filter is intended to reduce signals and focus on longer-term trends.

## Parameters To Test
- PSAR step / max: 0.01/0.10, 0.02/0.20, 0.03/0.30.
- SMA filter: 50/200, 75/200, 100/250.
- Trailing stop: 10%, 15%, 20%.
- Long-only vs symmetric long/short.

## Initial Risk Profile
Trend-following with fewer signals than raw PSAR. Main risk is late entry plus wide giveback during trend reversals.

## Pipeline-Verlauf
- G0: PENDING.

