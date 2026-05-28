---
ea_id: QM5_10307
slug: narang-blend
type: strategy
source_id: 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
sources:
  - "[[sources/narang-inside-black-box]]"
concepts:
  - "[[concepts/alpha-blending]]"
  - "[[concepts/trend-following]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 24
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS: Narang/Wiley/O'Reilly source cited; R2 PASS: fixed H4 EMA/RSI/ATR blended entry, exits, stops, and cost hurdle with ~24 trades/year/symbol; R3 PASS: OHLC/spread rules testable on DWX CFDs; R4 PASS: fixed rules, one-position, no ML/grid/martingale."
---

# Narang Fixed Blend Trend Reversion

## Quelle
- Source: [[sources/narang-inside-black-box]]
- URL: https://www.oreilly.com/library/view/inside-the-black/9780470432068/9780470432068_blending_alpha_models.html
- Author / institution: Rishi K Narang, Wiley / O'Reilly
- Location: Chapter 3, section 3.5 "Blending Alpha Models"; O'Reilly preview says quants can combine multiple alpha models and often use trend and reversion together.

## Mechanik

### Entry
- Evaluate once per completed H4 bar.
- Compute EMA(50), EMA(200), RSI(14), ATR(14), and estimated round-trip cost in points from spread plus configured commission proxy.
- Trend vote = +1 when EMA(50) > EMA(200), -1 when EMA(50) < EMA(200), else 0.
- Reversion vote = +1 when RSI(14) <= 35 and Close >= EMA(200), -1 when RSI(14) >= 65 and Close <= EMA(200), else 0.
- Blended score = trend vote + reversion vote.
- Enter long when blended score >= +1 and expected move proxy, 1.2 * ATR(14), is greater than 3x estimated round-trip cost.
- Enter short when blended score <= -1 and 1.2 * ATR(14) is greater than 3x estimated round-trip cost.
- Hold at most one position per magic number.

### Exit
- Exit long when blended score <= 0, RSI(14) >= 60, or after 18 H4 bars.
- Exit short when blended score >= 0, RSI(14) <= 40, or after 18 H4 bars.
- Exit either side on the ATR stop.

### Stop Loss
- Initial stop: 2.2 * ATR(14).
- Trail by 2.2 * ATR(14) after +1R.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter
- Cost hurdle is mandatory; no entry unless the expected move proxy clears transaction costs.
- Skip entry during configured rollover/high-spread window.

## Concepts
- [[concepts/alpha-blending]] - primary
- [[concepts/trend-following]] - secondary
- [[concepts/mean-reversion]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named book/author/publisher plus O'Reilly URL and ISBN 9780470432068. |
| R2 Mechanical | PASS | Fixed votes, score threshold, cost hurdle, exits, and stops are deterministic. |
| R3 Data Available | PASS | Uses OHLC-derived indicators and spread/commission proxy available or configurable for DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed weights and thresholds; no ML, optimization at runtime, grid, or martingale. |

## R3
Suitable for DWX FX, index, metals, and oil CFDs. If SP500.DWX is used, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Narang's blending section supports combining multiple alpha models rather than relying on one signal type.
- Narang's transaction-cost framework supports avoiding trades whose benefit does not clear the cost hurdle.

## Parameters To Test
- EMA pairs: 20/100, 50/200, 80/240.
- RSI reversion triggers: 30/70, 35/65, 40/60.
- Cost hurdle multiple: 2x, 3x, 4x.
- Time exit: 12, 18, 24 H4 bars.

## Initial Risk Profile
Hybrid model should trade less than pure reversion and reduce some whipsaw exposure, but it can also dilute strong standalone signals. Fixed votes avoid adaptive weighting and keep R4 clean.

## Pipeline-Verlauf
- G0: PENDING.
