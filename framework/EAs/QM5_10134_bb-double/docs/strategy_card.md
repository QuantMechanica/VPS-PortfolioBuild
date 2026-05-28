---
ea_id: QM5_10134
slug: bb-double
type: strategy
source_id: d3c009d7-a8d6-5251-b572-4777b207c2b9
sources:
  - "[[sources/raposa-python-backtests]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/bollinger-bands]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 18
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-19
g0_approval_reasoning: "R1 verifiable Raposa URL; R2 deterministic BB entries/exits with 18 trades/year/symbol estimate; R3 OHLC Bollinger rules portable to DWX incl SP500.DWX caveat; R4 fixed non-ML one-position logic."
---

# Double Bollinger Band Breakout

## Quelle
- Source: [[sources/raposa-python-backtests]]
- URL: https://raposa.trade/blog/4-simple-strategies-to-trade-bollinger-bands/
- Author / institution: Raposa
- Date: 2021-07-21
- Location: section "Double Bollinger Band Breakout" and `DoubleBBBreakout`

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute TP = (high + low + close) / 3.
- Compute inner Bollinger Bands with period 20 and 1 standard deviation.
- Compute outer Bollinger Bands with period 20 and 2 standard deviations.
- Enter long when close > inner upper band.
- Enter short when close < inner lower band.

### Exit
- Exit long when close <= inner upper band, or when close > outer upper band.
- Exit short when close >= inner lower band, or when close < outer lower band.

### Stop Loss
- Source has no explicit stop. Use V5 emergency stop in P1/P2 while preserving the band rules as the strategy exit.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter
- Warmup: 20 D1 bars.
- Optional variant: long-only on equity-index CFDs.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/volatility-breakout]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Verifiable Raposa URL with visible title, institution, and date. |
| R2 Mechanical | PASS | Inner-band entry and inner/outer-band exits are explicit. |
| R3 Data Available | PASS | OHLC-only Bollinger rules port to DWX indices, FX, metals, and oil. |
| R4 ML Forbidden | PASS | Fixed bands and one-position rules; no ML, grid, or martingale. |

## R3
SP500.DWX is valid for backtest-only S&P analog testing. Live promotion T6 gate requires NDX.DWX or WS30.DWX parallel validation if SP500.DWX is the only passing instrument.

## Author Claims
- Source says the double-band model reduced volatility versus the simpler breakout.
- Source says it still outperformed buy-and-hold in the example.

## Parameters To Test
- Period: 10, 20, 30.
- Inner sigma: 0.75, 1.0, 1.25.
- Outer sigma: 1.75, 2.0, 2.5.
- Long-only vs symmetric long/short.

## Initial Risk Profile
Trend breakout with an overshoot exit designed to cut positions when the move stretches too far. Risk is whipsaw during repeated band crosses.

## Pipeline-Verlauf
- G0: PENDING.

