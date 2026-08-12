---
ea_id: QM5_10706
slug: tv-mon-ls
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "andrei_keenvent, Monday Liquidity Sweep - WolfWeb, TradingView open-source strategy, updated 2026-05-22, https://www.tradingview.com/script/FyQv2kdT-Monday-Liquidity-Sweep-WolfWeb/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/weekly-range]]"
  - "[[concepts/mean-reversion]]"
indicators: []
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 42
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL/handle cited; R2 PASS mechanical Monday range sweep entry, stop, TP, BE and Friday exit with ~42 trades/year/symbol; R3 PASS DWX OHLC/time testable; R4 PASS fixed non-ML one-position rules."
---

# TradingView Monday Liquidity Sweep

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Monday Liquidity Sweep - WolfWeb`, author handle `andrei_keenvent`, open-source strategy, updated 2026-05-22, https://www.tradingview.com/script/FyQv2kdT-Monday-Liquidity-Sweep-WolfWeb/

## Mechanik

### Entry
Use H1 baseline on FX majors, gold, and index CFDs.

- Define the Monday box with configurable broker hour shift; source default shift is 7 hours.
- Track Monday high and Monday low only during the Monday box.
- After Monday completes, monitor sweeps through Monday high/low.
- Sweep must exceed the Monday level by at least `liqPct`; source default is 0.0002.
- Skip sweeps whose wick exceeds `maxWickPct`; source default is 0.0025.
- Short setup:
  - After Monday, price wicks above Monday high by at least `liqPct`.
  - Wick size is not larger than `maxWickPct`.
  - Next candle closes back inside the Monday range.
  - Entry mode allows trade day: Tuesday-only or one-trade-per-week.
  - Enter short.
- Long setup is symmetric below Monday low.
- Only one trade per week.

### Exit
- Take profit = max(R:R target, Monday range percentage target).
- Source defaults: R:R target 3.5R and Monday range target 130%.
- Move stop to locked breakeven when either:
  - Trade reaches configured R multiple, source current text uses 1.5R in main description.
  - Trade remains open for `beBars`, source default 24 bars.
- Force-close any open trade on Friday at NY open + 2 hours.

### Stop Loss
- Short stop = sweep wick high + wick high * `slPct`; source default `slPct` = 0.0002.
- Long stop = sweep wick low - wick low * `slPct`.
- Breakeven lock moves stop to entry plus a fraction of initial risk; P2 tests 0.1 and disables the inconsistent release-note value of 2.0.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Source fixed-dollar risk is replaced by V5 sizing.

### Zusatzliche Filter
- P2 baseline uses one-trade-per-week mode, not multiple attempts.
- P2 baseline requires next-candle close back inside Monday range.
- Friday force-close is mandatory to avoid weekend gap exposure.

## Concepts (was ist das fur eine Strategie)
- [[concepts/liquidity-sweep]] - fades failed breaks of Monday high/low.
- [[concepts/weekly-range]] - Monday establishes the week-defining reference range.
- [[concepts/mean-reversion]] - entry requires rejection back into the Monday range.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `andrei_keenvent` are cited. |
| R2 Mechanical | PASS | Source defines Monday range, sweep thresholds, entry timing, stop, TP, breakeven, and Friday close. |
| R3 Data Available | PASS | Uses OHLC, weekday/time, and percentage thresholds available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed non-ML rules; one trade per week, no grid, no martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX.

If SP500.DWX later becomes the only profitable index backtest, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy tracks Monday high and low and only draws a Monday box.
- Source says sweeps must happen after Monday and entries must be back inside the Monday range on the next candle.
- Source says entry mode can be Tuesday-only or one-trade-per-week.

## Parameters To Test
- Entry mode: Tuesday only, one trade per week.
- `liqPct`: 0.0001, 0.0002, 0.0004.
- `maxWickPct`: 0.0015, 0.0025, 0.0040.
- `slPct`: 0.0001, 0.0002, 0.0004.
- R:R target: 2.0, 3.0, 3.5.
- Monday range TP: 100%, 130%, 160%.
- Breakeven trigger: 1.5R, 2.0R, 3.0R.

## Initial Risk Profile
Weekly range-reversal system with low but acceptable cadence across a basket. Main risks are sparse single-symbol sample size, broker-time Monday-box alignment, and strong weekly continuation after Monday breakout.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10687 tv-parent-sweep
- QM5_10705 tv-liq-trap

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
