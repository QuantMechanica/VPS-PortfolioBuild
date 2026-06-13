---
ea_id: QM5_10615
slug: mql5-pivotstop
type: strategy
source_id: b8b5125a-c67f-5bbc-baff-33456e08f5b2
sources:
  - "[[sources/mql5-codebase-mt5-strategies]]"
concepts:
  - "[[concepts/pivot-level-entry]]"
  - "[[concepts/support-resistance-targets]]"
  - "[[concepts/intraday-time-stop]]"
indicators:
  - "[[indicators/daily-pivot]]"
g0_status: APPROVED
r1_track_record: PASS
r1_reasoning: "Single source_id present; named MQL5 CodeBase author (Fedoseev), title, and publish/update dates cited."
r2_mechanical: PASS
r2_reasoning: "Daily pivot hit entry with SR-level SL/TP exits is implementable; direction mapping is a tolerable gap Codex resolves from source code."
r3_data_available: PASS
r3_reasoning: "Daily OHLC pivot logic portable to DWX FX, metals, and index CFDs."
r4_ml_forbidden: PASS
r4_reasoning: "Fixed pivot-level system, one position per magic, no ML or adaptive parameters."
pipeline_phase: G0
last_updated: 2026-05-22
expected_trades_per_year_per_symbol: 120
card_body_incomplete: true
card_body_missing: "target_symbols"
g0_approval_reasoning: "R1 PASS MQL5 CodeBase URL/title/author cited; R2 PASS deterministic daily-pivot touch entry with SR SL/TP and estimated 120 trades/year/symbol; R3 PASS OHLC pivot logic portable to DWX CFDs; R4 PASS no ML/adaptive/grid/martingale and one-position-per-magic."
---

# MQL5 Daily Pivot Touch Stop System

## Quelle
- Source: [[sources/mql5-codebase-mt5-strategies]]
- CodeBase URL: https://www.mql5.com/en/code/1053
- Article: "gpfTCPivotStop - expert for MetaTrader 5", Dmitry Fedoseev, published 2012-11-14, updated 2016-11-22; rewritten from MQL4 code by George-on-Don.
- Page / Timestamp: MQL5 CodeBase expert page describing daily pivot/SR levels, entries when closed-bar price hits the pivot point, and SL/TP at support/resistance levels.

## Mechanik

### Entry
On each completed intraday bar below D1:
- Calculate daily Pivot plus three support and resistance levels from D1 bars.
- Open a position when the closed-bar close hits the daily Pivot point.
- Direction follows the source pivot-stop implementation: long if the pivot touch resolves upward from the pivot context; short if it resolves downward.
- One open position per symbol/magic.

### Exit
- Place Stop Loss and Take Profit at the configured daily support/resistance levels.
- If level spacing is too tight for broker stop constraints, use second support/resistance for Stop Loss and third opposite-side level for Take Profit.
- Optional source behavior: when first support/resistance is reached and TP is farther, move Stop Loss to entry plus spread.
- If `isTradeDay` baseline is enabled, close any open position at 23:00 broker time.

### Stop Loss
Primary source stop at daily support/resistance level. Baseline catastrophic fallback: `2.0 * ATR(14)` if pivot levels are unusable.

### Position Sizing
Fixed $1,000 P2 risk equivalent, one position per symbol/magic. V5 baseline disables consecutive-loss lot-reduction side logic.

### Zusätzliche Filter
- Baseline timeframe: M30/H1 because source requires timeframe smaller than D1.
- Optional P3 sweep: target level 1/2/3, intraday close on/off, breakeven modification on/off.

## Concepts (was ist das für eine Strategie)
- [[concepts/pivot-level-entry]] - primary
- [[concepts/support-resistance-targets]] - secondary
- [[concepts/intraday-time-stop]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Public MQL5 CodeBase URL with named author, title, publish/update dates, and downloadable source file. |
| R2 Mechanical | PASS/UNKNOWN | Source defines daily pivot calculation, pivot-hit entries, and support/resistance SL/TP; build must confirm exact direction mapping from source code. |
| R3 Data Available | PASS | Daily pivot/SR logic uses OHLC bars and is portable to DWX FX, metals, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed pivot-level system; no ML, adaptive parameters, grid, martingale, or multiple positions per magic. Loss-based lot reduction is excluded from V5 baseline. |

## R3
No special custom-symbol caveat. Baseline can run on DWX FX majors and crosses.
Target symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from MQL5 CodeBase page-37 continuation batch.
- P1: TBD
- P2: TBD

## Verwandte Strategien
- [[strategies/QM5_10616_mql5-pivotlimit]] - related daily pivot support/resistance bounce system.

## Lessons Learned (während Pipeline-Lauf)
- TBD
