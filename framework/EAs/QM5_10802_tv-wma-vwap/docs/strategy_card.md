---
ea_id: QM5_10802
slug: tv-wma-vwap
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Algomist_, Algomist.app v1.0, TradingView open-source strategy, published Dec 28 2025 and updated Jan 3, https://www.tradingview.com/script/wp0V0TVO-Algomist-app-v1-0/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/momentum-crossover]]"
  - "[[concepts/vwap-filter]]"
  - "[[concepts/atr-risk]]"
indicators:
  - "[[indicators/wma]]"
  - "[[indicators/vwap]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 20
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL/author cited; R2 PASS mechanical WMA cross VWAP/ATR-filter entries/exits with ATR bracket and ~20 trades/year/symbol (WMA50/100 cross is a slow-MA event, VWAP-side gated; original 80/yr over-claim corrected 2026-06-16); R3 PASS OHLC/WMA/VWAP-proxy/ATR testable on DWX symbols; R4 PASS fixed rules no ML/grid/martingale."
---

# TradingView WMA VWAP Momentum Scalper

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Algomist.app v1.0`, author handle `Algomist_`, open-source strategy, published 2025-12-28 and updated 2026-01-03, accessed 2026-05-22, https://www.tradingview.com/script/wp0V0TVO-Algomist-app-v1-0/

## Mechanik

### Entry
Use M5/M15 baseline.

- Compute WMA(50), WMA(100), session VWAP, and ATR.
- Long setup:
  - WMA(50) crosses above WMA(100).
  - Price is above VWAP.
  - ATR is above a minimum volatility threshold.
  - Bar is closed.
- Short setup:
  - WMA(50) crosses below WMA(100).
  - Price is below VWAP.
  - ATR is above a minimum volatility threshold.
  - Bar is closed.

### Exit
- Stop loss: default 3.0 * ATR from entry.
- Take profit: default 9.0 * ATR from entry, equivalent to 3R.
- Optional V5 signal exit: opposite WMA crossover before stop/target.

### Stop Loss
- Long: entry minus 3.0 * ATR.
- Short: entry plus 3.0 * ATR.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic. Ignore source webhook sizing and use framework sizing only.

### Zusatzliche Filter
- Optional London/NY session filter.
- Optional max spread and news blackout from V5 defaults.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum-crossover]] - WMA cross is the directional trigger.
- [[concepts/vwap-filter]] - VWAP side confirms participation.
- [[concepts/atr-risk]] - ATR controls stop and target width.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Algomist_` are cited. |
| R2 Mechanical | PASS | Source gives WMA crossover, VWAP side, ATR filter, stop, and target rules. |
| R3 Data Available | PASS | WMA, VWAP proxy, ATR, OHLC, and sessions are available on DWX symbols. |
| R4 ML Forbidden | PASS | Fixed crossover rules; no ML, grid, martingale, or online adaptive parameters. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX.

If this is later tested primarily on SP500.DWX, live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the primary signal is WMA(50) crossing WMA(100).
- Source says VWAP side and minimum ATR filter confirm entries.
- Source default risk uses 3.0 * ATR stop and 9.0 * ATR take profit.

## Parameters To Test
- WMA fast/slow: 20/50, 50/100.
- ATR minimum threshold: off, 20th percentile, 30th percentile.
- ATR stop: 2.0, 3.0, 4.0.
- ATR target: 4.0, 6.0, 9.0.
- Timeframe: M5, M15, M30.

## Initial Risk Profile
High-cadence crossover strategy with wide 3R bracket. Watch slippage and low-volatility filter sensitivity on short timeframes.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10800 tv-ema-vwap
- QM5_10787 tv-ema-rsi-adx

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
