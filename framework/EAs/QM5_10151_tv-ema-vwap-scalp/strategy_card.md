---
ea_id: QM5_10151
slug: tv-ema-vwap-scalp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/scalping]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/vwap]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 600
last_updated: 2026-05-19
g0_approval_reasoning: "R1 cites exact TradingView URL/author; R2 deterministic EMA/VWAP crossover entries plus ATR SL/TP/reversal/trailing exits with ~600 trades/year/symbol; R3 portable to DWX FX/gold/index CFDs with SP500 T6 caveat; R4 fixed-rule no ML/martingale one-position."
---

# TradingView EMA VWAP Scalper

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Ultimate Scalping Strategy v2`, author handle `sebamarghella`, updated 2025-11-01, https://www.tradingview.com/script/n45dOuob-Ultimate-Scalping-Strategy-v2/

## Mechanik

### Entry
Use 1-minute, 3-minute, or 5-minute bars.

- Long: fast EMA(9) crosses above slow EMA(21) and close is above session VWAP.
- Short: fast EMA(9) crosses below slow EMA(21) and close is below session VWAP.
- Baseline disables optional engulfing-candle and volume-spike filters for first P2 pass; test them later as parameter variants.

### Exit
- Exit at ATR take-profit, default 2.0 ATR from entry.
- Exit on opposite valid signal if reversal exit is enabled.
- Optional trailing-stop variant: activate after price moves favorably by a configurable ATR multiple, then trail by ATR distance.

### Stop Loss
- Initial stop at 1.5 ATR from entry.
- If trailing-stop mode is enabled, trailing stop replaces fixed take-profit after activation.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Trade only during liquid intraday sessions for the selected CFD.
- For index CFD ports, prefer NDX.DWX, WS30.DWX, and SP500.DWX M1/M5.
- Spread filter required because the source timeframe is scalping.

## Concepts (was ist das fur eine Strategie)
- [[concepts/scalping]] - primary
- [[concepts/trend-following]] - EMA/VWAP directional filter

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `sebamarghella` are cited. |
| R2 Mechanical | PASS | Source gives explicit EMA crossover, VWAP side filter, ATR stop/target, optional filters, and reversal/trailing exits. |
| R3 Data Available | PASS | OHLC/VWAP/ATR logic ports to DWX FX, gold, and index CFDs. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | No ML, neural, grid, martingale, online parameter adaptation, or pyramiding described. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10133_tv-ema80-scalp]] - related EMA scalping card with band retest logic.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
