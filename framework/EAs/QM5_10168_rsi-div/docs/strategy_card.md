---
ea_id: QM5_10168
slug: rsi-div
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/divergence]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/relative-strength-index]]"
  - "[[indicators/swing-pivots]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 15
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL; R2 mechanical RSI divergence pivots/exits with ~15 trades/year/symbol; R3 OHLC/RSI logic portable to DWX CFDs; R4 fixed rules no ML/martingale."
---

# RSI Divergence Reversal

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/test-and-trade-rsi-divergence-in-python/
- Author / institution: Raposa
- Date: 2021-07-26
- Location: sections "Divergences as Entry Signals", "Detecting Divergences", and "Building an RSI Divergence Model".

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute RSI(14).
- Confirm swing highs/lows using pivot order = 5 bars on each side and K = 2 consecutive pivots.
- Enter long when price confirms lower lows while RSI confirms higher lows and RSI < 50.
- Enter short when price confirms higher highs while RSI confirms lower highs and RSI > 50.

### Exit
- For a long, exit when RSI is still below 50 and falls below the RSI value recorded at entry.
- For a short, exit when RSI is still above 50 and rises above the RSI value recorded at entry.
- Exit when RSI crosses the 50 centerline in the opposite direction of the position.

### Stop Loss
- Initial long stop below the confirming price pivot low minus 1.0 * ATR(14).
- Initial short stop above the confirming price pivot high plus 1.0 * ATR(14).

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One active position per symbol and magic number.

### Zusätzliche Filter
- Warmup: 60 D1 bars.
- Pivot confirmation is delayed by `order` bars to avoid lookahead.
- Ignore a new divergence while a position from the prior divergence is open.

## Concepts
- [[concepts/divergence]] - primary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Raposa article URL with title, author/institution, and visible date. |
| R2 Mechanical | PASS | Source provides algorithmic pivot detection plus explicit long/short divergence and exit rules. |
| R3 Data Available | PASS | Uses only OHLC close, RSI, and pivots; portable to DWX FX, metals, oil, and indices. |
| R4 ML Forbidden | PASS | Fixed lookbacks and thresholds; no ML, adaptive parameters, grid, or martingale. |

## R3
The XOM stock example ports to SP500.DWX / NDX.DWX / WS30.DWX or to liquid FX/index CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source reports the pure RSI divergence model reduced volatility and drawdown in the worked example, while also warning that it underperformed for a long stretch.

## Parameters To Test
- RSI period: 10, 14, 21.
- Pivot order: 3, 5, 8.
- Consecutive pivot count K: 2, 3.
- Centerline: 45, 50, 55.
- ATR stop buffer: 0.5, 1.0, 1.5.

## Initial Risk Profile
Sparse reversal strategy. The delayed pivot confirmation reduces repaint risk but can enter late; long losing periods are plausible.

## Pipeline-Verlauf
- G0: PENDING.

