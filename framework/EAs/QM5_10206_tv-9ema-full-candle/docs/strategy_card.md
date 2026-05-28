---
ea_id: QM5_10206
slug: tv-9ema-full-candle
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/intraday-momentum]]"
indicators:
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 EMA full-candle entry and EMA-cross exit mechanical with ~180 trades/year/symbol; R3 testable on SP500.DWX backtest-only plus live NDX/WS30 caveat; R4 fixed rules no ML/grid/martingale one-position compatible."
---

# TradingView 9 EMA Full Candle Continuation

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `9 EMA First Full Candle Entry + EMA Cross Exit (Strategy)`, author handle `myttthew`, published 2026-02-10, https://www.tradingview.com/script/aUCZlh4q-9-EMA-First-Full-Candle-Entry-EMA-Cross-Exit-Strategy/

## Mechanik

### Entry
Use M5 as the source timeframe.

- Compute EMA(9) on close.
- A qualifying long candle is the first bar after a non-qualifying state where the full candle closes above EMA(9): `low > EMA9`.
- A qualifying short candle is the first bar after a non-qualifying state where the full candle closes below EMA(9): `high < EMA9`.
- Enter long on the qualifying long candle close.
- Enter short on the qualifying short candle close.
- Do not add repeated entries while candles remain fully on the same side of EMA(9).

### Exit
- Exit long when price crosses back below EMA(9).
- Exit short when price crosses back above EMA(9).

### Stop Loss
Source does not define a protective stop beyond the EMA exit. Add V5 emergency stop at 2.0 * ATR(14), recalculated at entry and fixed until exit.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: SP500.DWX, NDX.DWX, WS30.DWX, GER40.DWX, XAUUSD.DWX.
- Trade only during the most liquid session for the symbol: US RTH for US index analogs, London/NY overlap for GER40/XAUUSD.
- Spread must be <= 10% of emergency stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - follows candles that fully clear the fast EMA.
- [[concepts/intraday-momentum]] - M5 continuation system intended for liquid intraday markets.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `myttthew` are cited. |
| R2 Mechanical | PASS | Source gives exact EMA-side entry and EMA-cross exit rules. |
| R3 Data Available | PASS | EMA and OHLC are available on DWX index CFDs and gold. Live promotion T6 gate: SP500.DWX is not broker-routable. If the EA passes P0-P9 on SP500.DWX only, T6 deploy requires a parallel-validation on NDX.DWX or WS30.DWX before AutoTrading enable. |
| R4 ML Forbidden | PASS | Fixed EMA rules, no ML, no adaptive parameters, no grid, no martingale. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10115_tv-ma-scalper-relief]] - short-term MA scalping family, but this card uses a single EMA with full-candle qualification.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
