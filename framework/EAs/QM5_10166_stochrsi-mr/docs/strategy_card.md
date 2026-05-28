---
ea_id: QM5_10166
slug: stochrsi-mr
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/oscillator-extreme]]"
indicators:
  - "[[indicators/stochastic-rsi]]"
  - "[[indicators/relative-strength-index]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 40
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL; R2 deterministic StochRSI entry/exit with ~40 trades/year/symbol; R3 close-only oscillator portable to DWX CFDs; R4 fixed rules no ML/martingale."
---

# Stochastic RSI Extreme Mean Reversion

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/2-ways-to-trade-the-stochastic-rsi-in-python/
- Archive reference: https://raposa.trade/blog/?p=2
- Author / institution: Raposa
- Date: 2021-07-05
- Location: archive entry "2 Ways To Trade The Stochastic RSI In Python"; subtitle states Stochastic RSI is applied to mean-reverting and momentum strategies.

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute RSI(14) on close.
- Compute StochRSI(14) = 100 * (RSI - rolling_min_RSI_14) / (rolling_max_RSI_14 - rolling_min_RSI_14).
- Enter long when StochRSI crosses up from below 20.
- Enter short when StochRSI crosses down from above 80.

### Exit
- Exit long when StochRSI crosses above 50.
- Exit short when StochRSI crosses below 50.
- Exit on opposite entry signal and reverse only after the prior position is closed.

### Stop Loss
- Research default emergency stop: 2.5 * ATR(14) from entry.
- P3 can sweep ATR multiple 1.5, 2.0, 2.5, 3.0.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One position per magic number.

### Zusätzliche Filter
- Warmup: 30 D1 bars.
- Optional P3 filter: only take long signals when close > SMA(200) and short signals when close < SMA(200).
- Friday close uses framework default unless P3 explicitly tests weekend hold.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/oscillator-extreme]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL and archive listing with title, date, and author/institution. |
| R2 Mechanical | PASS | StochRSI threshold entry and centerline exit are deterministic; side stop is a Research default. |
| R3 Data Available | PASS | Requires only close-derived RSI/StochRSI and ports to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed lookbacks and thresholds; no ML, online adaptation, grid, martingale, or multi-position stacking. |

## R3
Equity examples can be ported to SP500.DWX / NDX.DWX / WS30.DWX. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source frames StochRSI as useful for identifying over-extended moves and explicitly presents a mean-reversion use case.

## Parameters To Test
- RSI period: 10, 14, 21.
- StochRSI lookback: 10, 14, 21.
- Entry thresholds: 10/90, 20/80, 30/70.
- Exit threshold: 45/55, 50, opposite extreme.
- Trend filter: off, SMA(200), EMA(200).

## Initial Risk Profile
Fast oscillator mean reversion. Expected to trade more often than plain RSI and to suffer in persistent trend regimes unless the optional trend filter helps.

## Pipeline-Verlauf
- G0: PENDING.

