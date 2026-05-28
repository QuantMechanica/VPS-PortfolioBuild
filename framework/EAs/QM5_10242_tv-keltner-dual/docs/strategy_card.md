---
ea_id: QM5_10242
slug: tv-keltner-dual
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/volatility-channel]]"
  - "[[concepts/trend-following]]"
indicators:
  - "[[indicators/keltner-channel]]"
  - "[[indicators/ema]]"
  - "[[indicators/atr-stop]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 60
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL cited; R2 mechanical Keltner/EMA entries and exits with ATR stops and ~60 trades/year/symbol; R3 DWX CFD ports incl indices/gold/oil; R4 no ML/grid/martingale."
---

# Keltner Dual Mode

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script page, "Keltner Channel Strategy" by adkhomepros, published 2025-03-20.
- URL: https://www.tradingview.com/script/OQGzolcI-Keltner-Channel-Strategy/

## Mechanik

### Entry
- Baseline supports two source-defined modes; P1 should expose mode as an input and default to trend-following for cleaner interpretation.
- Reversal mode long: price crosses below the lower Keltner Band.
- Reversal mode short: price crosses above the upper Keltner Band.
- Trend mode long: EMA9 crosses above EMA21 and price is above EMA50.
- Trend mode short: EMA9 crosses below EMA21 and price is below EMA50.

### Exit
- Reversal mode long exits when price crosses back above the Keltner middle band.
- Reversal mode short exits when price crosses back below the Keltner middle band.
- Trend mode long exits when EMA9 crosses back below EMA21.
- Trend mode short exits when EMA9 crosses back above EMA21.
- ATR stop and ATR target can close earlier.

### Stop Loss
- Long stop: 1.5 ATR below entry.
- Short stop: 1.5 ATR above entry.
- Target: 2.0 ATR in favor of entry.

### Position Sizing
- V5 fixed-risk baseline: risk USD 1,000 per P2 backtest trade.
- One open position per magic number.

### Zusätzliche Filter
- Source highlights XAUUSD, NASDAQ/NQ, crude oil, and trending assets; DWX ports: XAUUSD.DWX, XTIUSD.DWX, NDX.DWX, GER40.DWX, SP500.DWX.
- Recommended source timeframes: M15, H1, H4, D1. P2 baseline should start with H1/H4 to avoid excessive noise.
- Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable.

## Concepts (was ist das für eine Strategie)
- [[concepts/volatility-channel]] - primary
- [[concepts/trend-following]] - secondary

## R1-R4 Bewertung
| Kriterium | Status | Begründung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle adkhomepros are cited. |
| R2 Mechanical | PASS | Keltner band crosses, EMA cross trend entries, indicator exits, ATR stops, and ATR targets are explicit. |
| R3 Data Available | PASS | OHLC, EMA, ATR, and Keltner Channels are available on DWX CFDs. |
| R4 ML Forbidden | PASS | No ML, neural logic, grid, martingale, DCA, pyramiding, or online parameter adaptation. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING.
- P1: TBD.
- P2: TBD.

## Verwandte Strategien
- [[strategies/QM5_10225_tv-keltner-gc]] - Keltner breakout with MA50/MA200 trend gate.
- [[strategies/QM5_10243_tv-bb-kc-vol]] - BB/KC cross volatility comparison.

## Lessons Learned (während Pipeline-Lauf)
- TBD.

---

*Knoten-Pflege: bei jeder Pipeline-Phase-Änderung `pipeline_phase` aktualisieren + `last_updated`. Bei FAIL: `pipeline_phase: DEAD` + Lessons-Learned-Eintrag.*
