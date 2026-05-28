---
ea_id: QM5_10348
slug: et-gann-pivot
type: strategy
source_id: d6ae8bae-7b94-5209-9be7-fb72a1c3e3fe
source_citation: "Elite Trader forum thread, The Gann Pivot Indicator: A Deep Dive into the Trading Philosophy and Mechanics, 2025, https://www.elitetrader.com/et/threads/the-gann-pivot-indicator-a-deep-dive-into-the-trading-philosophy-and-mechanics.385857/"
sources:
  - "[[sources/elite-trader-algo-mech]]"
concepts:
  - "[[concepts/pivot-breakout]]"
  - "[[concepts/price-action-reversal]]"
  - "[[concepts/intraday-risk-control]]"
indicators:
  - "[[indicators/pivot-high-low]]"
  - "[[indicators/atr]]"
  - "[[indicators/sma]]"
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
period: M15
expected_trade_frequency: "Pivot signal with 50-bar expiration and max daily trades; conservative estimate 60 trades/year/symbol after filters."
expected_trades_per_year_per_symbol: 60
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
last_updated: 2026-05-21
g0_approval_reasoning: "R1 source URL present; R2 mechanical pivot breakout/exit rules with 60 trades/year/symbol estimate; R3 DWX OHLC/ATR/SMA testable; R4 fixed-rule no ML/grid/martingale."
---

# Elite Trader Gann Pivot Signal System

## Quelle
- Source: [[sources/elite-trader-algo-mech]]
- URL: https://www.elitetrader.com/et/threads/the-gann-pivot-indicator-a-deep-dive-into-the-trading-philosophy-and-mechanics.385857/
- Author / handle: Elite Trader thread author visible on page; card cites thread URL as primary source.
- Date: 2025 thread.
- Location: Pine strategy code section defines `Gann Pivot Trading System`, `gannDays = 4`, `sigExpir = 50`, stop/target options, time filter, MA filter, and `maxDailyTrades = 5`.

## Mechanik

### Entry
- Evaluate on completed M15 bars.
- Detect pivot highs/lows using a symmetric `PivotLookback = gannDays = 4` bars; only confirm a pivot after the right-side bars close.
- Create a buy signal when price closes above the most recent confirmed pivot high plus one tick before `sigExpir = 50` bars elapse.
- Create a sell signal when price closes below the most recent confirmed pivot low minus one tick before `sigExpir = 50` bars elapse.
- Optional MA filter baseline enabled for P2: long only if close > SMA(50,M15), short only if close < SMA(50,M15).
- Maximum one trade per direction per symbol per day; one active position per symbol/magic.

### Exit
- Baseline TP = 2R.
- Exit at configured intraday time if time filter is enabled; P2 baseline uses 15:45 local liquid-session exit for index CFDs and no intraday time exit for FX unless P3 selects it.
- Exit long if close breaks below the latest confirmed pivot low.
- Exit short if close breaks above the latest confirmed pivot high.

### Stop Loss
- Baseline SL = `2.0 * ATR(14,M15)`.
- Alternative P3 stop: pivot-based stop beyond the triggering pivot by `0.25 * ATR(14,M15)`.
- Optional trailing stop: `1.5 * ATR(14,M15)` after +1R.

### Position Sizing
- P2 baseline: `RISK_FIXED = 1000`.
- Fixed-size source input is not used for V5 live sizing.

### Zusaetzliche Filter
- Max daily trades = 5 as in source code, tightened to 2 for P2 baseline.
- Trade only during liquid sessions.
- Skip if spread > 2.5x rolling median spread.

## Concepts
- [[concepts/pivot-breakout]] - price crosses confirmed pivot.
- [[concepts/price-action-reversal]] - latest pivot can act as invalidation.
- [[concepts/intraday-risk-control]] - source includes stops, targets, trailing, time filters, and max daily trades.

## R1-R4 Bewertung
| Kriterium | Status | Begruendung |
|-----------|--------|------------|
| R1 Source-Link | PASS | Full Elite Trader thread URL and thread title. |
| R2 Mechanical | PASS | Pine strategy code exposes pivot confirmation, signal expiry, stop/target, filters, and max daily trades. |
| R3 DWX-testbar | PASS | Uses OHLC-derived pivots, ATR, and SMA on DWX FX/metals/indices. |
| R4 No ML | PASS | Fixed pivot/risk inputs; no ML, adaptive parameters, grid, or martingale. |

## R3
Primary P2 basket: `EURUSD.DWX`, `GBPUSD.DWX`, `XAUUSD.DWX`, `GER40.DWX`, `NDX.DWX`. Optional SP500.DWX backtest-only index variant must carry the standard T6 caveat if promoted from SP500-only evidence.

## Author Claims
- The source code names the strategy "Gann Pivot Trading System."
- The code comments describe it as a complete trading system with risk management.

## Parameters To Test
- Gann days / pivot lookback: 3, 4, 6, 8.
- Signal expiration: 20, 50, 80 bars.
- Stop type: ATR, pivot-based.
- ATR stop multiplier: 1.5, 2.0, 2.5.
- Profit target: 1.5R, 2.0R, 3.0R.
- Max daily trades: 1, 2, 5.

## Initial Risk Profile
Pivot breakout/reversal system with moderate whipsaw risk if pivots are too short. Non-lookahead confirmation is critical; implementation must wait for right-side pivot bars before arming signals.

## Pipeline-Verlauf
- G0: 2026-05-21, PENDING.

## Lessons Learned
- TBD during pipeline run.
