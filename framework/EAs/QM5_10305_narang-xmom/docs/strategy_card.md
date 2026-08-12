---
ea_id: QM5_10305
slug: narang-xmom
type: strategy
source_id: 0f051e46-12b2-51f3-aad5-d6d8bd3e9b35
sources:
  - "[[sources/narang-inside-black-box]]"
concepts:
  - "[[concepts/cross-sectional-momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/rate-of-change]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
expected_trades_per_year_per_symbol: 20
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 named Narang/OReilly source URL; R2 deterministic weekly basket ROC ranking entries/exits/stops with >=2 trades/year/symbol defensible at basket cadence; R3 DWX multi-asset weekly OHLC basket testable; R4 fixed thresholds one-position no ML/grid/martingale."
---

# Narang Cross-Asset Relative Momentum

## Quelle

- Source: [[sources/narang-inside-black-box]]
- URL: https://www.oreilly.com/library/view/inside-the-black/9780470432068/9780470432068_blending_alpha_models.html
- Author / institution: Rishi K Narang, Wiley / O'Reilly
- Location: Chapter 3, section 3.5 "Blending Alpha Models"; O'Reilly preview discusses using alpha strategies across time horizons, trade structures, instruments, and geographies.

## Mechanik

### Entry

- Evaluate once per completed W1 bar across a configured DWX basket.
- Compute 13-week rate of change for every enabled symbol.
- Rank symbols by 13-week return.
- For a single-symbol EA build, enter long on the chart symbol when it is in the top 30% of the configured basket and its own 13-week return > 0.
- Enter short on the chart symbol when it is in the bottom 30% of the configured basket and its own 13-week return < 0.
- Hold at most one position per magic number.

### Exit

- Exit long when the symbol falls below the top 50% rank or its 13-week return turns negative.
- Exit short when the symbol rises above the bottom 50% rank or its 13-week return turns positive.
- Also exit after 8 W1 bars if no rank exit has fired.

### Stop Loss

- Initial stop: 3.0 * ATR(14) on D1.
- Trail weekly by 3.0 * ATR(14) after +1.5R.

### Position Sizing

- P2 baseline: fixed $1,000 risk convention.

### Zusätzliche Filter

- Basket must contain at least 8 active DWX symbols with valid weekly data.
- Skip entry if the chart symbol's weekly spread/ATR ratio is above the configured V5 cap.

## Concepts

- [[concepts/cross-sectional-momentum]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung

| Kriterium | Status | Begründung |
|---|---|---|
| R1 Track Record | PASS | Named book/author/publisher plus O'Reilly URL and ISBN 9780470432068. |
| R2 Mechanical | PASS | Ranking, entry, exit, stop, time exit, and basket validity checks are deterministic. |
| R3 Data Available | PASS | Uses weekly OHLC data available across DWX FX/index/commodity CFDs. |
| R4 ML Forbidden | PASS | Fixed rank thresholds and lookbacks; no ML/adaptive/grid/martingale. |

## R3

Initial basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, AUDUSD.DWX, USDCAD.DWX, XAUUSD.DWX, DE40.DWX, NDX.DWX, WS30.DWX, XTIUSD.DWX. If SP500.DWX is used, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

Build mapping: the validated V5 DWX matrix uses `GDAXI.DWX` as the canonical DAX instrument, so the implementation ports the card's `DE40.DWX` label to the already approved and registered `GDAXI.DWX` symbol.

## Author Claims

- Narang classifies trend as a theory-driven alpha category.
- Narang's blending discussion supports using alpha approaches across multiple instruments and geographies for diversification.

## Parameters To Test

- Momentum lookback: 8, 13, 26 weeks.
- Entry percentile: top/bottom 20%, 30%, 40%.
- Rank exit: 40%, 50%, 60%.
- Time exit: 6, 8, 12 weeks.

## Initial Risk Profile

Cross-sectional momentum can cluster risk during macro reversals. The single-position-per-magic build tests each symbol separately, while any portfolio-level long/short balance is deferred to Q12.

## Pipeline-Verlauf

- G0: APPROVED.
