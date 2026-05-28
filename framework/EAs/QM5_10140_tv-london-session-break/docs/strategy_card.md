---
ea_id: QM5_10140
slug: tv-london-session-break
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/session-breakout]]"
  - "[[concepts/opening-range]]"
indicators: []
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL and author cited; R2 mechanical London range breakout entries, stop, 2R target, and time exit with ~180 trades/year/symbol; R3 testable on NDX.DWX/WS30.DWX and SP500.DWX backtest-only caveat; R4 no ML/grid/martingale/multi-position."
---

# TradingView London Session Break

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `London Session Breakout - Joovier Gems`, author handle `EddyPips`, published 2026-05-18, https://www.tradingview.com/script/JkVblAXK-London-Session-Breakout-Joovier-Gems/

## Mechanik

### Entry
Use 5-minute bars. In New York time:

- Build London range from 03:00 to 09:00 using session high and session low.
- Trade only between 09:30 and 11:00.
- Enter long at close of first 5-minute candle closing above London range high.
- Enter short at close of first 5-minute candle closing below London range low.
- Baseline: one signal per day.

### Exit
- Take profit at 2R by default.
- Close at session end if the position remains open after the New York execution window plus a configurable grace period.

### Stop Loss
Source stop is 5 ticks beyond the breakout candle. For DWX CFD baseline, convert to either 0.25 ATR on M5 or symbol-specific minimum tick equivalent, whichever is larger.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Extended-hours data required for source-like NQ behavior. Port primarily to NDX.DWX and secondarily to WS30.DWX/SP500.DWX.
- No entries outside 09:30-11:00 New York time.
- Daily range must be nonzero and complete before trade window opens.

## Concepts (was ist das fur eine Strategie)
- [[concepts/session-breakout]] - primary
- [[concepts/opening-range]] - session range construction

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `EddyPips` are cited. |
| R2 Mechanical | PASS | Source gives closed-form session range, entry window, long/short triggers, stop, and 2R target. |
| R3 Data Available | PASS | Source is NQ-focused; port to NDX.DWX for live-tradable Nasdaq CFD and SP500.DWX for backtest-only S&P analog. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, adaptive online parameters, or pyramiding described. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular script page.

## Verwandte Strategien
- [[strategies/QM5_9988_tv-opening-range-breakout-dual]] - related opening-range breakout card.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
