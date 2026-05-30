---
ea_id: QM5_10167
slug: stochrsi-mom
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/oscillator-centerline]]"
indicators:
  - "[[indicators/stochastic-rsi]]"
  - "[[indicators/relative-strength-index]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 35
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL; R2 deterministic StochRSI centerline entry/exit with ~35 trades/year/symbol; R3 close-only oscillator portable to DWX CFDs; R4 fixed rules no ML/martingale."
---

# Stochastic RSI Centerline Momentum

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
- Compute RSI(14), then StochRSI(14).
- Enter long when StochRSI crosses above 50.
- Enter short when StochRSI crosses below 50.

### Exit
- Exit long when StochRSI crosses below 80 after having been above 80, or when StochRSI crosses below 50.
- Exit short when StochRSI crosses above 20 after having been below 20, or when StochRSI crosses above 50.
- Reverse only after the current position is closed.

### Stop Loss
- Research default emergency stop: 3.0 * ATR(14) from entry.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.
- One position per magic number.

### Zusätzliche Filter
- Warmup: 30 D1 bars.
- Optional P3 filter: require SMA(50) slope to agree with the position direction.
- Use closed bars only; no intra-bar StochRSI updates.

## Concepts
- [[concepts/momentum]] - primary
- [[concepts/oscillator-centerline]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL and archive listing with named author/institution and date. |
| R2 Mechanical | PASS | Centerline entries and extreme/reversal exits are deterministic. |
| R3 Data Available | PASS | Close-only oscillator logic ports directly to DWX FX, commodities, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator periods and thresholds; no adaptive learning or multi-position logic. |

## R3
Equity examples can be ported to SP500.DWX / NDX.DWX / WS30.DWX. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source presents StochRSI as a fast oscillator usable for momentum as well as mean-reversion systems.

## Parameters To Test
- RSI period: 10, 14, 21.
- StochRSI lookback: 10, 14, 21.
- Centerline: 45, 50, 55.
- Exhaustion exit: 15/85, 20/80, 30/70.
- SMA slope filter: off, SMA(50), SMA(100).

## Initial Risk Profile
Momentum oscillator model with whipsaw risk around the centerline. It may work best on symbols with clean directional persistence.

## Pipeline-Verlauf
- G0: PENDING.

