---
ea_id: QM5_10176
slug: sma-ext-mr
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/moving-average-extension]]"
indicators:
  - "[[indicators/simple-moving-average]]"
  - "[[indicators/average-true-range]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 45
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source Raposa URL/date; R2 deterministic SMA extension entries/exits with ~45 trades/year/symbol; R3 ports to DWX CFDs with SP500 T6 caveat; R4 fixed non-ML one-position rules."
---

# SMA Extension Mean Reversion

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/how-to-build-your-first-mean-reversion-trading-strategy-in-python/
- Mirror/reference: https://medium.com/raposa-technologies/how-to-build-your-first-mean-reversion-trading-strategy-in-python-8c9d4813ee40
- Author / institution: Raposa / Raposa Technologies
- Date: 2021-03-01
- Location: article sections "Developing a Mean-Reverting Strategy" and "Testing the Basic System".

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute SMA(close, 20).
- Define `extension = close[1] - SMA20[1]`.
- Enter long when `extension < 0`, meaning the close is below its recent average.
- Enter short when `extension > 0`, meaning the close is above its recent average.
- Reverse only after closing the prior position; one position per magic number.

### Exit
- Exit long when close crosses back above SMA20.
- Exit short when close crosses back below SMA20.
- If an opposite signal appears while a position is open, close the current position at the next bar open and then apply the new direction on the following bar.

### Stop Loss
- Research default emergency stop: 2.0 * ATR(14) from entry.
- P3 can sweep ATR multiple 1.5, 2.0, 2.5, 3.0.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One active position per symbol and magic number.

### Zusätzliche Filter
- Warmup: 30 D1 bars.
- Use closed bars only.
- Optional P3 no-trade filter: skip if ATR(14) is below its own 60-bar median, to avoid tiny extensions in flat regimes.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/moving-average-extension]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa article URL plus Medium mirror with named institution and date. |
| R2 Mechanical | PASS | Close-vs-SMA extension entry and SMA re-cross exit are deterministic; emergency stop is a Research default. |
| R3 Data Available | PASS | Uses only close, SMA, and ATR; portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed lookback, fixed thresholds, one-position state machine, no ML, grid, martingale, or adaptive parameters. |

## R3
The source examples are equity-style daily bars. The rule ports directly to SP500.DWX / NDX.DWX / WS30.DWX and liquid FX/commodity CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source presents the system as a beginner mean-reversion backtest that compares price with a recent average and trades the deviation back toward that average.

## Parameters To Test
- SMA period: 10, 20, 30, 50.
- Entry threshold: any extension, 0.25 ATR, 0.50 ATR.
- Exit: SMA re-cross, half-extension reversion, opposite signal.
- ATR stop: 1.5, 2.0, 2.5, 3.0.

## Initial Risk Profile
Simple daily mean-reversion system. Expected to trade moderately often and to suffer in persistent trends unless the safety-threshold variant or a volatility filter improves selectivity.

## Pipeline-Verlauf
- G0: PENDING.

