---
ea_id: QM5_10169
slug: rsi-div-trend
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/divergence]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/relative-strength-index]]"
  - "[[indicators/exponential-moving-average]]"
  - "[[indicators/swing-pivots]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 12
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 source URL present; R2 mechanical RSI divergence entry and EMA/RSI exits with ~12 trades/year/symbol; R3 portable to DWX symbols with SP500 T6 caveat; R4 fixed-rule no ML one-position."
---

# RSI Divergence With EMA Trend Conversion

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/test-and-trade-rsi-divergence-in-python/
- Author / institution: Raposa
- Date: 2021-07-26
- Location: section "RSI Divergence and Trend".

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute RSI(14), EMA(50), and EMA(200).
- Confirm swing highs/lows using pivot order = 5 and K = 2.
- Enter long when price confirms lower lows while RSI confirms higher lows and RSI < 50.
- Enter short when price confirms higher highs while RSI confirms lower highs and RSI > 50.

### Exit
- For a long, normally exit when RSI remains below 50 and falls below entry RSI.
- Keep the long open instead if EMA(50) > EMA(200).
- Exit the long when the RSI exit condition is active and EMA(50) <= EMA(200).
- For a short, normally exit when RSI remains above 50 and rises above entry RSI.
- Keep the short open instead if EMA(50) < EMA(200).
- Exit the short when the RSI exit condition is active and EMA(50) >= EMA(200).

### Stop Loss
- Initial long stop below the confirming price pivot low minus 1.0 * ATR(14).
- Initial short stop above the confirming price pivot high plus 1.0 * ATR(14).
- Optional trailing stop after trend conversion: 4.0 * ATR(14).

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One active position per symbol and magic number.

### Zusätzliche Filter
- Warmup: 220 D1 bars for EMA(200).
- Pivot confirmation is delayed by `order` bars to avoid lookahead.
- Treat divergence entry and trend hold as one continuous position, not separate stacked entries.

## Concepts
- [[concepts/divergence]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full Raposa article URL with title, author/institution, and date. |
| R2 Mechanical | PASS | Source provides explicit divergence entries and EMA(50/200) trend-conversion hold rules. |
| R3 Data Available | PASS | OHLC/close-derived indicators port directly to DWX FX, commodities, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed RSI/pivot/EMA parameters and one-position state logic; no ML or adaptive online learning. |

## R3
The XOM stock example ports to SP500.DWX / NDX.DWX / WS30.DWX or to liquid FX/index CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source reports that adding the EMA trend condition improved returns in the worked example, while warning that the test is a single-instrument vectorized demonstration.

## Parameters To Test
- RSI period: 10, 14, 21.
- Pivot order: 3, 5, 8.
- EMA pair: 20/100, 50/200, 64/256.
- ATR stop buffer: 0.5, 1.0, 1.5.
- Trend-conversion trailing stop: off, 3.0 ATR, 4.0 ATR.

## Initial Risk Profile
Hybrid reversal-to-trend strategy. Fewer entries than oscillator-only systems; risk comes from late pivot confirmation and trend-conversion giveback.

## Pipeline-Verlauf
- G0: PENDING.

