---
ea_id: QM5_10304
slug: narang-revert
type: strategy
source_id: 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
sources:
  - "[[sources/narang-inside-black-box]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/price-related-alpha]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/rsi]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 35
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 named Narang/OReilly source URL; R2 deterministic H4 Bollinger/RSI/ADX entries, exits, ATR stop with ~35 trades/year/symbol plausible; R3 price-derived DWX CFD testable; R4 fixed params one-position no ML/grid/martingale."
---

# Narang Price Reversion Band Fade

## Quelle
- Source: [[sources/narang-inside-black-box]]
- URL: https://www.oreilly.com/library/view/inside-the-black/9780470432068/9780470432068_theory-driven_alpha_models.html
- Author / institution: Rishi K Narang, Wiley / O'Reilly
- Location: Chapter 3, section 3.2 "Theory-Driven Alpha Models"; O'Reilly preview lists reversion as a theory-driven alpha category and says trend/mean reversion are price-related.

## Mechanik

### Entry
- Evaluate once per completed H4 bar.
- Compute Bollinger Bands(20, 2.0), RSI(14), ATR(14), and EMA(200).
- Enter long when Close < lower Bollinger band, RSI(14) <= 30, and Close is within 1.5 * ATR(14) of EMA(200).
- Enter short when Close > upper Bollinger band, RSI(14) >= 70, and Close is within 1.5 * ATR(14) of EMA(200).
- Hold at most one position per magic number.

### Exit
- Exit long when Close >= Bollinger middle band or after 12 H4 bars, whichever occurs first.
- Exit short when Close <= Bollinger middle band or after 12 H4 bars, whichever occurs first.
- Exit either side on the ATR stop.

### Stop Loss
- Initial stop: 1.8 * ATR(14) from entry.
- No averaging down and no grid.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter
- Skip entry when ADX(14) > 28 to avoid strong trend regimes.
- Skip around high-spread rollover window configured by V5 defaults.

## Concepts
- [[concepts/mean-reversion]] - primary
- [[concepts/price-related-alpha]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named book/author/publisher plus O'Reilly URL and ISBN 9780470432068. |
| R2 Mechanical | PASS | Entry, exit, time stop, protective stop, and no-grid constraint are deterministic. |
| R3 Data Available | PASS | Uses price-derived indicators available on DWX CFDs. |
| R4 ML Forbidden | PASS | Fixed parameters and one-position-per-magic; no ML, adaptive sizing, martingale, or grid. |

## R3
Best initial symbols are range-prone FX majors/crosses and selected indices. If SP500.DWX is used, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Narang classifies reversion as one of the core theory-driven alpha categories.
- Narang's visible framework distinguishes price-related alpha inputs from fundamental inputs.

## Parameters To Test
- Bollinger lookback/deviation: 20/2.0, 30/2.0, 20/2.5.
- RSI trigger: 25/75, 30/70, 35/65.
- ADX trend filter: 22, 28, 34.
- Time exit: 8, 12, 18 H4 bars.

## Initial Risk Profile
Mean-reversion profile: frequent smaller wins with tail risk during regime shifts and persistent trends. The stop and ADX filter are mandatory because the source is a category framework, not a complete risk recipe.

## Pipeline-Verlauf
- G0: PENDING.
