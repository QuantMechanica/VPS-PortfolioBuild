---
ea_id: QM5_10183
slug: carver-multi-sig
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/multi-signal-ensemble]]"
indicators:
  - "[[indicators/moving-average-crossover]]"
  - "[[indicators/donchian-channel]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 10
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL plus Rob Carver attribution; R2 deterministic aggregate MAC/MBO entry and fixed volatility-stop exit with ~10 trades/year/symbol; R3 OHLC-derived rules portable to DWX CFDs with SP500 T6 caveat; R4 fixed rules, no ML/martingale/grid, one net position."
---

# Carver Multi Signal Starter Trend System

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/a-complete-system-for-new-traders-adding-entry-signals/
- Mirror/reference: https://readmedium.com/a-complete-system-for-new-traders-adding-entry-signals-afa1c8765f8e
- Author / institution: Raposa, adapting Rob Carver's Starter System from Leveraged Trading
- Date: 2021-11-01
- Location: sections "Adding Entry Signals", "Starter System 2.0", and the complete `StarterSystem` code.

## Mechanik

### Entry
- Evaluate once per completed D1 bar after all warmup windows are available.
- Compute four moving-average crossover signals:
  - `MAC8_32 = +1` when SMA(8) > SMA(32), `-1` when SMA(8) < SMA(32).
  - `MAC16_64 = +1` when SMA(16) > SMA(64), `-1` when SMA(16) < SMA(64).
  - `MAC32_128 = +1` when SMA(32) > SMA(128), `-1` when SMA(32) < SMA(128).
  - `MAC64_256 = +1` when SMA(64) > SMA(256), `-1` when SMA(64) < SMA(256).
- Compute five mean-breakout signals using close position inside rolling close range:
  - For N in 20, 40, 80, 160, 320, calculate `SPriceN = (Close - SMA(Close,N)) / (HighestClose(N) - LowestClose(N))`.
  - `MBON = +1` when `SPriceN > 0`, `-1` when `SPriceN < 0`, otherwise 0.
- Aggregate active signals using the source top-down weights; V5 baseline uses equal weights inside the MAC family and equal weights inside the MBO family, with MAC family weight 50% and MBO family weight 50%.
- Enter long when weighted aggregate signal > 0 and the current position is flat or short.
- Enter short when weighted aggregate signal < 0 and the current position is flat or long.

### Exit
- Exit long when the fixed volatility stop is hit.
- Exit short when the fixed volatility stop is hit.
- If flat and aggregate signal is zero, remain flat.
- Baseline does not continuously flip on aggregate-signal reversal; it follows the source's stopped starter-system lineage before the later no-stop continuous variant.

### Stop Loss
- Source stop model from the starter-system series: set stop distance from the rolling instrument risk estimate.
- V5 baseline: at entry, set stop at `entry_price - 0.5 * annualized_volatility * entry_price` for longs and `entry_price + 0.5 * annualized_volatility * entry_price` for shorts, where annualized volatility is 252-day close-to-close standard deviation.
- P3 may convert the stop to an equivalent ATR(252) or ATR(14) multiplier for MT5 execution stability, but the baseline should preserve the source's volatility-stop intent.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- Source uses target-risk volatility sizing; V5 build should keep one net position per magic number and should not hold separate sub-signal positions.

### Zusätzliche Filter
- Warmup: 340 D1 bars to cover the longest 320-day breakout and 256-day SMA.
- Shorts enabled by default; long-only is a P3 variant.
- Carry/dividend signal is excluded from the V5 baseline because CFD symbols do not provide a clean equity-dividend carry analog. A no-carry version is explicitly tested in the source article.
- Do not pyramid, rebalance, or dynamically scale exposure by forecast strength.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/multi-signal-ensemble]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL with Rob Carver attribution and visible archive date. |
| R2 Mechanical | PASS | Source code gives exact MAC, MBO, aggregate signal, stop-loss, and position-state rules. |
| R3 Data Available | PASS | No-carry baseline uses only OHLC/close-derived data and ports to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed rules and fixed lookbacks; no ML, no online learning, no martingale/grid, and V5 constrains the card to one net position. |

## R3
Stock examples can be ported to SP500.DWX / NDX.DWX / WS30.DWX and to liquid FX/metals/oil DWX CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says adding entry signals allows the system to look across multiple indicators simultaneously before making the investment.
- Source says the no-carry and carry versions both outperformed the worked baselines in total return, while volatility stayed high enough to keep Sharpe closer to the S&P 500.

## Parameters To Test
- Signal families: MAC only, MBO only, MAC + MBO.
- Family weights: 50/50 baseline, 70/30 MAC/MBO, 30/70 MAC/MBO.
- MA pairs: default set vs 16/64 only vs 8/32 + 16/64 + 32/128.
- MBO lengths: default set vs 20/40/80 only.
- Stop model: source volatility stop, ATR(252) proxy, ATR(14) proxy.
- Shorts: enabled vs long-only.

## Initial Risk Profile
Slow D1 trend-following ensemble with long lookbacks and stopped exits. It may trade infrequently per symbol and can whipsaw during broad sideways ranges, but the stop-loss lineage gives a bounded single-position implementation unlike the later continuous/no-stop and forecast-scaled variants.

## Pipeline-Verlauf
- G0: PENDING.

