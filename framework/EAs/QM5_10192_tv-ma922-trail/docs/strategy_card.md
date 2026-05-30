---
ea_id: QM5_10192
slug: tv-ma922-trail
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [NDX.DWX, GER40.DWX, WS30.DWX, SP500.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/breakout]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/atr]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 90
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL/author cited; R2 mechanical MA breakout plus trailing/opp-cross exits with ~90 trades/year/symbol; R3 DWX index CFD/SP500 backtest portable; R4 fixed-rule no ML/grid/martingale one-position compatible."
---

# TradingView MA 9/22 Breakout Trail

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `9:22 5 MIN 15 MIN BANKNIFTY`, author handle `ashokkumarsand`, published 2023-06-04, https://www.tradingview.com/script/5MQm4L0J-9-22-5-MIN-15-MIN-BANKNIFTY/

## Mechanik

### Entry
Use M5/M15 bars.

- Compute fast MA(9), slow MA(22), and ATR(14).
- Long entry:
  - fast MA crosses above slow MA.
  - Breakout confirmation enabled: close exceeds recent swing high by at least 0.5 * ATR(14).
  - Minimum candle body percentage >= 0.5 of full candle range.
  - Optional filters frozen ON for baseline: current volume above its 20-bar SMA and RSI(14) > 50.
- Short entry:
  - fast MA crosses below slow MA.
  - close breaks recent swing low by at least 0.5 * ATR(14).
  - body and optional volume/RSI mirror filters pass.
- One open position maximum.

### Exit
- Source exit is a trailing stop-loss based on a percentage of average entry price.
- Baseline trailing stop = 1.5% from average entry, updated only in the profitable direction.
- Close on opposite MA cross if it occurs before trailing stop.

### Stop Loss
Initial stop = max(1.5% price distance, 1.0 * ATR(14)) from entry, then trail by source 1.5%.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Source instrument is BANKNIFTY; DWX port uses index CFDs: NDX.DWX, GER40.DWX, WS30.DWX, SP500.DWX backtest-only analog.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.
- Spread must be <= 15% of initial stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - MA cross plus trailing stop.
- [[concepts/breakout]] - requires price breakout confirmation beyond recent structure.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `ashokkumarsand` are cited. |
| R2 Mechanical | PASS | Source gives MA lengths, ATR filter, breakout/body filters, buy/sell cross rules, and trailing stop. |
| R3 Data Available | PASS | Uses OHLC, tick volume, ATR, RSI, and moving averages; ported from BANKNIFTY to DWX index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicators and trailing stop, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10116_tv-multi-ma-exit]] - MA-cross family, but this card uses 9/22 MA plus breakout and trailing-stop management.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
