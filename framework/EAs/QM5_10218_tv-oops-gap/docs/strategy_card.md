---
ea_id: QM5_10218
slug: tv-oops-gap
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/gap-reversal]]"
  - "[[concepts/intraday-mean-reversion]]"
indicators:
  - "[[indicators/daily-high-low]]"
  - "[[indicators/session-filter]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 30
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical gap reclaim entry, day-extreme stop, session exit with ~30 trades/year/symbol; R3 testable on DWX CFDs incl SP500 backtest caveat; R4 fixed non-ML one-position rules."
---

# TradingView Larry Williams Oops Gap

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Larry Williams Oops Strategy`, author handle `xtradernet`, published 2025-10-10, https://www.tradingview.com/script/7Gqs0Sqn-Larry-Williams-Oops-Strategy/

## Mechanik

### Entry
Use M5 or M15 intraday execution with daily bars for setup. Long setup: today opens below yesterday's low and yesterday's candle was bearish. Place a buy stop at yesterday's low plus a configurable tick filter. Short setup: today opens above yesterday's high and yesterday's candle was bullish. Place a sell stop at yesterday's high minus the tick filter. Longs are taken only on down-gap days; shorts only on up-gap days.

### Exit
Force-close all positions at the end of the session or the last available intraday bar. No fixed take-profit.

### Stop Loss
For longs, trail the protective stop at the current day's low. For shorts, trail the protective stop at the current day's high. Add V5 emergency cap at 3.0 * ATR(14) from entry if the day-extreme stop is too wide for baseline risk.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Use exchange/session open appropriate to the target symbol. For SP500.DWX, treat the US cash open as the reference session. Do not carry overnight.

## Concepts (was ist das fur eine Strategie)
- [[concepts/gap-reversal]] - fades an opening gap after price reclaims the prior day's extreme.
- [[concepts/intraday-mean-reversion]] - assumes the gap overshoots and reverses intraday.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `xtradernet` are cited. |
| R2 Mechanical | PASS | Source gives daily gap setup, stop-order entry, day-extreme stop, and end-session exit. |
| R3 Data Available | PASS | Daily OHLC, intraday OHLC, session timing, and day-extreme stops are available for DWX index/gold CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | Fixed gap rules and one intraday position; no ML, grid, martingale, or adaptive online parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10139_tv-gap-or-break]] - opening gap fill/continuation family.
- [[strategies/QM5_10210_tv-turtle-ny-sweep]] - NY index intraday reversal family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
