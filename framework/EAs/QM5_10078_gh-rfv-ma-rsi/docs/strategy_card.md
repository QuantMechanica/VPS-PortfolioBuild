---
ea_id: QM5_10078
slug: gh-rfv-ma-rsi
type: strategy
source_id: 3b3ec48a-0755-5187-9331-afb36e174175
sources:
  - "[[sources/github-mql5-stars-20]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum-pullback]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; full GitHub URL with named author rafaelfvcs / Rafael FVCS."
r2_mechanical: PASS
r2_reasoning: "EMA 12/32 crossover plus RSI threshold, fixed 30-point SL, and timed close are deterministic."
r3_data_available: PASS
r3_reasoning: "Target symbols EURUSD/GBPUSD/USDJPY/XAUUSD.DWX use EMA and RSI derived from standard DWX OHLC data."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed EMA and RSI parameters; no ML, adaptive logic, grid, or martingale; one position per magic."
pipeline_phase: G0
expected_trades_per_year_per_symbol: 50
last_updated: 2026-05-19
card_body_incomplete: true
card_body_missing: "period"
g0_approval_reasoning: "R1 linked GitHub source; R2 deterministic EMA/RSI entry with fixed SL/TP/timed close and ~50 trades/year/symbol; R3 DWX OHLC indicators testable; R4 fixed non-ML one-position rules."
---

# GitHub Rafael FVCS MA Cross RSI Confluence

## Quelle
- Source: [[sources/github-mql5-stars-20]]
- Citation: Rafael FVCS / rafaelfvcs, `MA_CROS_RSI.mq5`, GitHub, accessed 2026, URL https://github.com/rafaelfvcs/Introduction-to-MetaTrader5-and-MQL5---book/blob/master/MA_CROS_RSI.mq5.
- Page / Timestamp: `rafaelfvcs/Introduction-to-MetaTrader5-and-MQL5---book`, `MA_CROS_RSI.mq5`, https://github.com/rafaelfvcs/Introduction-to-MetaTrader5-and-MQL5---book/blob/master/MA_CROS_RSI.mq5
- Source-code author/institution: rafaelfvcs / Rafael FVCS, repository for `Introduction to MetaTrader 5 and Programming with MQL5`.

## Mechanik

### Entry
- Run on M15 baseline unless build-phase sweep overrides the chart period.
- Process entries only on a newly opened bar.
- Calculate fast EMA 12 and slow EMA 32 on close.
- Calculate RSI 5 on close with oversold 30 and overbought 70 thresholds.
- Use the source `MA_AND_RSI` mode for this card to avoid duplicating pure MA-cross cards.
- Buy when fast EMA crosses above slow EMA and RSI is at or below 30.
- Sell when slow EMA crosses above fast EMA and RSI is at or above 70.
- Enter only when no position exists on the symbol. V5 constraint: one active position per symbol/magic.

### Exit
- Attached source take profit.
- At configured limit close time, close any open position.

### Stop Loss
- Source default stop loss: 30 points.

### Position Sizing
- Source default volume: fixed `num_lots`.
- V5 baseline: fixed risk $1,000 for P2.

### Zusatzliche Filter
- Source default time limit close: 17:40.
- Build phase must normalize close time to DWX broker time.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - primary
- [[concepts/momentum-pullback]] - secondary

## R3
Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Full GitHub file URL and named repository author/institution are cited. |
| R2 Mechanical | PASS | EMA cross, RSI threshold, fixed SL/TP, and timed close are deterministic. |
| R3 Data Available | PASS | EMA and RSI use OHLC-derived data available on DWX forex, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator parameters, no ML, no martingale, no grid, and one-position behavior. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.

## Verwandte Strategien
- [[strategies/QM5_10051_gh-ma-cross]] - rejected pure MA-cross draft; this card adds RSI confluence from a different repository.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Anderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
