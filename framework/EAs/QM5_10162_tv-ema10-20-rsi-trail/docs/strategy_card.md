---
ea_id: QM5_10162
slug: tv-ema10-20-rsi-trail
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/momentum]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 160
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 EMA/RSI/trailing/time-exit rules mechanical with expected 160 trades/year/symbol; R3 OHLC EMA/RSI ports to DWX CFDs; R4 no ML/grid/martingale and one-position compatible."
---

# TradingView EMA10 EMA20 RSI Trail

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `3 EMA + RSI with Trail Stop [Free990] (LOW TF)`, author handle `Free990`, updated 2025-01-14, https://www.tradingview.com/script/mgD7xBuw-3-EMA-RSI-with-Trail-Stop-Free990-LOW-TF/

## Mechanik

### Entry
Use M15 baseline bars.

- Calculate EMA(10), EMA(20), and EMA(100).
- Long: EMA(10) crosses above EMA(20), both EMA(10) and EMA(20) are above EMA(100), and the signal bar closes bullish.
- Short: EMA(10) crosses below EMA(20), both EMA(10) and EMA(20) are below EMA(100), and the signal bar closes bearish.
- If an opposite position exists, flatten before opening the new direction; baseline should enforce one active position only.

### Exit
- Long signal exit: RSI crosses above overbought threshold; baseline threshold 70.
- Short signal exit: RSI crosses below oversold threshold; baseline threshold 30.
- Time exit: if trade has been open for 24 bars and is profitable, close the position.
- Stop/trailing exit remains active while the signal/time exits are not triggered.

### Stop Loss
- Fixed percent stop from average entry price; baseline 1.5% for indices and 1.0 ATR(14) equivalent cap for FX if percent stop is too wide.
- Trailing stop activates after favorable movement; baseline use 1.5 ATR(14) trail distance and 1.0 ATR(14) offset.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Target Symbols
EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, DAX.DWX.

### Zusatzliche Filter
- Low-timeframe strategy; require spread <= 20% of initial stop distance.
- Disable pyramiding.
- Avoid trading outside the most liquid session for the chosen symbol in baseline.

## Concepts (was ist das fur eine Strategie)
- [[concepts/momentum]] - primary
- [[concepts/trend-following]] - EMA stack trend filter

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Free990` are cited. |
| R2 Mechanical | PASS | Source gives exact EMA cross/stack entries, RSI exits, time exit, fixed stop, and trailing stop mechanics. |
| R3 Data Available | PASS | EMA/RSI/OHLC strategy ports directly to DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, or live performance-adaptive parameter logic; trailing stop is deterministic. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10133_tv-ema80-scalp]] - related EMA hierarchy scalper.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
