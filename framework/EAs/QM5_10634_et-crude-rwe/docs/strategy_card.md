---
ea_id: QM5_10634
slug: et-crude-rwe
type: strategy
source_id: cf54ceef-f6e7-5fa0-ae03-98d3d4f8fe64
source_citation: "rajesheck, 70% success rate Crude Oil intraday strategy, Elite Trader, 2016-09-24 to 2016-09-29, https://www.elitetrader.com/et/threads/70-success-rate-crude-oil-intraday-strategy.303063/"
sources:
  - "[[sources/elite-trader-technical-analysis]]"
concepts:
  - "[[concepts/intraday-momentum]]"
  - "[[concepts/rally-wait-enter]]"
  - "[[concepts/time-boxed-breakout]]"
indicators: []
target_symbols: [XTIUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
period: M5
expected_trade_frequency: "Intraday momentum event requiring a 0.18%-0.50% move within 20 minutes plus rebreak; conservative estimate 60 trades/year/symbol."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; Elite Trader thread by rajesheck with full URL and date."
r2_mechanical: PASS
r2_reasoning: "Deterministic momentum-event rules: percentage-move threshold in 20-min window, fixed wait period, rebreak entry within deadline, bounded TP/SL/time exit."
r3_data_available: PASS
r3_reasoning: "Crude oil intraday concept ports to XTIUSD.DWX; XAUUSD/GER40/NDX are DWX CFDs sharing the intraday momentum-burst mechanism."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed percentage thresholds and timing windows, no ML/adaptive logic, one position per magic."
pipeline_phase: G0
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS source URL/handle; R2 PASS deterministic momentum event/wait/rebreak plus SL/TP/time-exit with ~60 trades/year/symbol; R3 PASS crude rule testable on XTIUSD.DWX and other CFDs; R4 PASS fixed non-ML one-position rules."
---

# Elite Trader Rally Wait Enter Momentum

## Quelle
- Source: [[sources/elite-trader-technical-analysis]]
- URL: https://www.elitetrader.com/et/threads/70-success-rate-crude-oil-intraday-strategy.303063/
- Author / handle: `rajesheck`.
- Date: 2016-09-24 to 2016-09-29.
- Location: post #1 gives the three-step rally, wait, crossover entry rule; posts #3-#5 clarify it is momentum/velocity based and chart-pattern dependent.

## Mechanik

### Entry
- Evaluate M5 bars during liquid broker hours for the symbol.
- Define a momentum event as price moving at least `0.35%` from a 20-minute rolling low to a subsequent high within 20 minutes for longs, or at least `0.35%` from rolling high to low for shorts.
- Long setup:
  - Detect upward momentum event.
  - Wait exactly 10 minutes after the event high is first printed.
  - Enter long when price trades above the event high within 60 minutes of the event high timestamp.
- Short setup mirrors long:
  - Detect downward momentum event.
  - Wait exactly 10 minutes after the event low.
  - Enter short when price trades below the event low within 60 minutes.

### Exit
- Primary TP: `1.2R`.
- Exit if price closes back inside the pre-event 20-minute range.
- Time exit after 12 M5 bars.

### Stop Loss
- Long SL below the low of the 20-minute momentum-event window minus `0.20 * ATR(14,M5)`.
- Short SL above the high of the 20-minute momentum-event window plus `0.20 * ATR(14,M5)`.

### Position Sizing
- P2 baseline: fixed $1,000 risk.
- One active position per symbol/magic.

### Zusaetzliche Filter
- Skip if 20-minute event range exceeds `3.0 * ATR(14,M5)` to avoid news spikes.
- Skip entries in the final two hours of Friday trading.
- P3 threshold sweep includes the author's 0.50% example and later 0.18% clarification.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL plus visible handle. |
| R2 Mechanical | PASS | Source gives directional event, wait, and rebreak; this card adds bounded exits and stops. |
| R3 DWX-testbar | PASS | Crude-oil intraday rule ports to XTIUSD.DWX and other liquid CFD momentum symbols. |
| R4 No ML | PASS | Fixed rules, one-position-per-magic, no ML/grid/martingale. |

## R3
Primary P2 basket: XTIUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.

## Author Claims
- rajesheck states the entry process as rally, wait, then enter on a crossover of the rally level.
- rajesheck later calls the method momentum or velocity based.

## Parameters To Test
- Momentum threshold: 0.18%, 0.35%, 0.50%.
- Event window: 15, 20, 30 minutes.
- Wait time: 5, 10, 15 minutes.
- Rebreak deadline: 30, 60, 90 minutes.
- TP: 1.0R, 1.2R, 1.5R.

## Pipeline-Verlauf
- G0: PENDING.

