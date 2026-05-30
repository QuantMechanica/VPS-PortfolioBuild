---
ea_id: QM5_10189
slug: tv-piv-vwap-brk
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/pivot-points]]"
  - "[[indicators/rsi]]"
  - "[[indicators/vwap]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 120
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL/author cited; R2 deterministic pivot/RSI/VWAP/volume breakout with ATR bracket and ~120 trades/year/symbol; R3 OHLCV/indicator logic testable on DWX FX/gold/index CFDs; R4 fixed rules, no ML/grid/martingale, one-position-per-magic compatible."
---

# TradingView Pivot RSI VWAP Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Instant Breakout Strategy with RSI & VWAP`, author handle `thetraderlodge`, published 2025-08-22, https://www.tradingview.com/script/4juJumUH-Instant-Breakout-Strategy-with-RSI-VWAP/

## Mechanik

### Entry
Use M5/M15 bars for DWX baseline, even though the source mentions 1-second charts.

- Detect latest confirmed pivot high and pivot low with left/right bars = 3.
- Long breakout: close crosses above latest pivot high.
- Short breakout: close crosses below latest pivot low.
- Strict-filter baseline enabled:
  - Current volume > SMA(volume, 20) * 1.5.
  - Long momentum: close is at least 1% above open; short momentum: close is at least 1% below open.
  - RSI(3) > 50 for long; RSI(3) < 50 for short.
  - Price above session VWAP for long; price below session VWAP for short.
- Reverse/close opposite side before opening a new signal; one open position maximum.

### Exit
- Source exit is bracket-based.
- Long TP = entry + 9.0 * ATR(14); long SL = entry - 1.0 * ATR(14).
- Short TP = entry - 9.0 * ATR(14); short SL = entry + 1.0 * ATR(14).
- Close any still-open position on opposite breakout signal.

### Stop Loss
ATR(14) stop at 1.0x ATR from entry, per source default.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Do not run on 1-second data in QM baseline; use M5/M15 to keep MT5 tick-test runtime bounded.
- Spread must be <= 15% of ATR stop distance.
- DWX targets: XAUUSD.DWX, EURUSD.DWX, GBPUSD.DWX, GER40.DWX, NDX.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - confirmed pivot level breakout.
- [[concepts/momentum]] - volume, candle momentum, RSI, and VWAP filters require active directional pressure.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `thetraderlodge` are cited. |
| R2 Mechanical | PASS | Source gives pivot detection, optional filters, breakout entries, and ATR bracket exits. |
| R3 Data Available | PASS | Uses OHLC, tick volume, RSI, VWAP, ATR, and pivots available on DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10186_tv-pivot-time-break]] - pivot breakout family, but this card adds RSI/VWAP/volume/momentum filters.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
