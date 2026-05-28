---
ea_id: QM5_10216
slug: tv-break-retest
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/support-resistance]]"
indicators:
  - "[[indicators/pivot-levels]]"
  - "[[indicators/trailing-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 pivot breakout-retest entries with stop/trailing exits and ~45 trades/year/symbol; R3 testable on DWX FX/gold/index CFDs; R4 fixed non-ML one-position rules."
---

# TradingView Breakout Retest

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Breaks and Retests - Free990`, author handle `Free990`, published 2024-11-26, https://www.tradingview.com/script/800ndgbX-Breaks-and-Retests-Free990/

## Mechanik

Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX.

### Entry
Use H1 baseline. Detect support and resistance from pivot levels over the source lookback range. Mark a bullish breakout when price closes above resistance, then wait for price to retest the broken resistance and hold it as support. Enter long after a valid retest in Long Only or Both mode. Mark a bearish breakout when price closes below support, then wait for price to retest the broken support and hold it as resistance. Enter short after a valid retest in Short Only or Both mode.

### Exit
Exit when the initial percentage stop or activated trailing stop is hit. If an opposite confirmed breakout-retest signal appears while a position is open, close the current position before considering the new direction.

### Stop Loss
Source stop is a user-defined percentage away from entry. Use 1.0% initial research default for indices/gold and ATR-equivalent normalization for FX if needed. Trailing stop activates after `profit_threshold_percent` and follows the best favorable price.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Require retest confirmation on a closed bar. Default to no same-bar breakout+retest entries. Skip entries where the retest distance is smaller than current spread plus 0.25 * ATR(14).

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - waits for a level break, then trades continuation.
- [[concepts/support-resistance]] - pivot-derived levels define the breakout and retest.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Free990` are cited. |
| R2 Mechanical | PASS | Source defines support/resistance detection, breakout, retest, direction modes, and stop/trailing exits. |
| R3 Data Available | PASS | Pivot, OHLC, percentage/ATR-equivalent stops, and trailing logic are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed pivot and stop rules, no ML, grid, martingale, or adaptive online parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10186_tv-pivot-time-break]] - pivot breakout with time filter.
- [[strategies/QM5_10184_tv-atr-zigzag-break]] - swing breakout with ATR bracket.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
