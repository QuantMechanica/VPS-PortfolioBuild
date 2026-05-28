---
ea_id: QM5_10303
slug: narang-trend
type: strategy
source_id: 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
sources:
  - "[[sources/narang-inside-black-box]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/time-series-momentum]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/adx]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 8
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 PASS cited Narang/OReilly; R2 PASS deterministic EMA/ADX trend entries/exits/stops with ~8 trades/year/symbol; R3 PASS DWX OHLC CFDs with SP500 caveat if used; R4 PASS fixed non-ML one-position rules."
---

# Narang Price Trend Continuation

## Quelle
- Source: [[sources/narang-inside-black-box]]
- URL: https://www.oreilly.com/library/view/inside-the-black/9780470432068/9780470432068_theory-driven_alpha_models.html
- Author / institution: Rishi K Narang, Wiley / O'Reilly
- Location: Chapter 3, section 3.2 "Theory-Driven Alpha Models"; O'Reilly preview lists trend as a theory-driven alpha category and identifies trend/mean reversion as price-related categories.

## Mechanik

### Entry
- Evaluate once per completed D1 bar.
- Compute EMA(50), EMA(200), ADX(14), and ATR(14).
- Enter long when Close > EMA(200), EMA(50) > EMA(200), and ADX(14) >= 20.
- Enter short when Close < EMA(200), EMA(50) < EMA(200), and ADX(14) >= 20.
- Hold at most one position per magic number.

### Exit
- Exit long when Close < EMA(50) or EMA(50) < EMA(200).
- Exit short when Close > EMA(50) or EMA(50) > EMA(200).
- Exit either side on the ATR stop.

### Stop Loss
- Initial stop: 2.5 * ATR(14) from entry.
- Trail stop by 2.5 * ATR(14) in the profitable direction only after the trade reaches +1R.

### Position Sizing
- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter
- Skip entries when spread exceeds the symbol's configured V5 spread cap.
- Warmup: 220 D1 bars.
- No Friday entry after 18:00 broker time.

## Concepts
- [[concepts/trend-following]] - primary
- [[concepts/time-series-momentum]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Named book/author/publisher plus O'Reilly URL and ISBN 9780470432068. |
| R2 Mechanical | PASS | Directional entry, exit, stop, sizing, and filters are deterministic; lookbacks are Codex defaults because Narang provides the category rather than parameters. |
| R3 Data Available | PASS | Uses OHLCV-derived indicators available on DWX FX, index, metals, and oil CFDs. |
| R4 ML Forbidden | PASS | Fixed rules, fixed parameters, one position per magic, no ML/adaptive/grid/martingale. |

## R3
Primary test set can use liquid DWX FX majors plus DE40.DWX, NDX.DWX, WS30.DWX, XAUUSD.DWX, and XTIUSD.DWX. If SP500.DWX is used, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Narang frames alpha models as the part of a quant system focused on making money and adding skill.
- The O'Reilly preview gives trend following as an example of skill that can generate profits.
- The same section classifies trend as one of the core theory-driven alpha categories.

## Parameters To Test
- EMA pairs: 20/100, 50/200, 100/300.
- ADX threshold: 15, 20, 25.
- ATR stop: 2.0, 2.5, 3.0.
- D1 vs H4 evaluation.

## Initial Risk Profile
Classic slow trend follower. Expected to lose in sideways regimes through whipsaws and to concentrate gains in persistent directional moves. Source is conceptual; parameter robustness must be decided by Q03, not by the book.

## Pipeline-Verlauf
- G0: PENDING.
