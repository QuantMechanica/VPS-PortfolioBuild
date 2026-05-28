---
ea_id: QM5_10223
slug: tv-bb-wd-break
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [NDX.DWX, GER40.DWX, WS30.DWX, SP500.DWX, XAUUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/momentum-breakout]]"
  - "[[concepts/seasonality-filter]]"
indicators:
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/exponential-moving-average]]"
  - "[[indicators/average-true-range]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 45
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical BB/EMA/wick/calendar entry plus BB/seasonal exit with ~45 trades/year/symbol; R3 DWX OHLC indicators testable incl SP500.DWX T6 caveat; R4 fixed rules no ML/grid/martingale one-position."
---

# TradingView Bollinger WD Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `0000 Bollinger W D Strat v14`, author handle `shitholed`, updated 2026-05-17, https://www.tradingview.com/script/JygL0tF0/

## Mechanik

### Entry
Long-only daily or H4 breakout. Enter when close is strictly above the upper Bollinger Band, close is above the selected trend moving average, default EMA55, close > close[2], total wick length is at least 10 times the real body, upper shadow is not greater than lower shadow * 3, the current date is not inside an active bad-season window, and the cooldown has elapsed.

### Exit
Exit if close drops below the lower Bollinger Band. Also exit during the source seasonal sell windows or quarter-month seasonality matrix when enabled.

### Stop Loss
Use source optional ATR stop as baseline: 0.2 * ATR from entry. Because this is very tight for DWX CFDs, include 0.5/1.0/1.5 * ATR in P3 sweep.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Use the quarter-month seasonality matrix only as a frozen calendar input, not as an adaptive optimization. For SP500.DWX tests, keep the standard live-promotion caveat.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum-breakout]] - trades close above sensitive upper Bollinger Band.
- [[concepts/seasonality-filter]] - blocks entries and forces exits during predefined weak calendar windows.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `shitholed` are cited. |
| R2 Mechanical | PASS | Source gives exact Bollinger breakout, EMA, momentum, wick/body, calendar, exit, TP, and SL rules. |
| R3 Data Available | PASS | OHLC, Bollinger Bands, EMA, ATR, and calendar filters are available on DWX index/gold CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | Calendar grid is fixed, not online-adaptive; no ML, grid, martingale, or performance-adaptive sizing. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_9984_tv-bb-outside-candle-scalping]] - Bollinger breakout/scalp family.
- [[strategies/QM5_10219_tv-open-impulse]] - impulse breakout family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
