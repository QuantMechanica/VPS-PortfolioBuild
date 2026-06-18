---
ea_id: QM5_10760
slug: tv-iu-orb
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Shivam_Mandrai, IU Opening range Breakout Strategy, TradingView open-source strategy, https://www.tradingview.com/script/JnOdejSN-IU-Opening-range-Breakout-Strategy/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/opening-range-breakout]]"
  - "[[concepts/session-flat]]"
indicators:
  - "[[indicators/session-range]]"
  - "[[indicators/previous-candle-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-22
g0_approval_reasoning: "R1 cites TradingView URL/author; R2 has opening-range breakout entries, previous-candle stops, RR target, session flat and ~180 trades/year/symbol; R3 OHLC/session logic works on DWX symbols; R4 fixed non-ML one-position logic."
---

# TradingView IU Opening Range Breakout

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `IU Opening range Breakout Strategy`, author handle `Shivam_Mandrai`, open-source strategy published 2024-12-12, https://www.tradingview.com/script/JnOdejSN-IU-Opening-range-Breakout-Strategy/

## Mechanik

### Entry
Use M5 baseline on intraday sessions.

- During the configured opening session, record opening-range high and opening-range low.
- After the opening range is complete:
  - Long when close crosses above opening-range high.
  - Short when close crosses below opening-range low.
- Entry is allowed only when no position is open.
- Enforce max trades per day; source default is two trades per day.

### Exit
- Long:
  - Stop loss at previous candle low.
  - Take profit from risk-to-reward ratio, default 2:1.
- Short:
  - Stop loss at previous candle high.
  - Take profit from risk-to-reward ratio, default 2:1.
- Force close all open positions at the configured session end; source default is 15:15.

### Stop Loss
- Previous completed candle low for longs.
- Previous completed candle high for shorts.
- P2 adds minimum stop-distance and maximum stop-distance guards to avoid one-tick or oversized stops.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- Opening-range window must be complete.
- Max trades per day default 2; P2 also tests 1 trade per day.
- No overnight exposure because of session-end close.

## Concepts (was ist das fur eine Strategie)
- [[concepts/opening-range-breakout]] - the locked session range defines breakout triggers.
- [[concepts/session-flat]] - positions are closed at the intraday session end.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Shivam_Mandrai` are cited. |
| R2 Mechanical | PASS | Source defines OR high/low construction, crossover/crossunder entries, previous-candle stops, 2:1 target, daily trade limit, and session-end flat. |
| R3 Data Available | PASS | OHLC and session mechanics are available on DWX FX, metals, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed mechanical rules; no ML, grid, martingale, or pyramiding requirement. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX, WS30.DWX. SP500.DWX is optional backtest-only. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Author Claims
- Source says the strategy identifies the high and low prices of the opening session.
- Source says long entry is triggered when price closes above the opening-range high and short entry when price closes below the opening-range low.
- Source says long stops use the previous candle low, short stops use the previous candle high, and targets use configurable risk-to-reward.

## Parameters To Test
- Opening range: 5, 15, 30, 45 minutes.
- Max trades/day: 1, 2.
- Risk-to-reward: 1.0, 1.5, 2.0, 2.5.
- Session end: 11:30, 15:15, 16:00 local market time.
- Stop guard min distance: 0.25 ATR, 0.5 ATR.
- Stop guard max distance: 2 ATR, 3 ATR.

## Initial Risk Profile
Simple ORB variant with high expected cadence and high overlap with existing ORB family. Its distinguishing feature is the previous-candle stop rather than opposite-range or ATR stop.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10654 tv-orb-width
- QM5_10751 tv-orb-ext-sl
- QM5_10730 tv-orb-sessions

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
