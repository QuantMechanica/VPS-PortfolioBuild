---
ea_id: QM5_10188
slug: tv-adx-di-ema-long
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/momentum]]"
indicators:
  - "[[indicators/adx]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 65
last_updated: 2026-05-19
g0_approval_reasoning: "R1 PASS exact TradingView URL/author cited; R2 PASS fixed EMA + DMI/ADX entry/exit/stop with ~65 trades/year/symbol; R3 PASS OHLC indicators portable to DWX FX/gold/index CFDs; R4 PASS no ML/grid/martingale and one-position-per-magic compatible."
---

# TradingView ADX DI EMA Long

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `ADX strategy (considering ADX and +DI only)`, author handle `eemani123`, published 2020-09-17, https://www.tradingview.com/script/G4RNcGXg-ADX-strategy-considering-ADX-and-DI-only/

## Mechanik

### Entry
Use H1 or H4 bars, long-only baseline.

- Compute fast EMA(13) and slow EMA(55).
- Compute DMI/ADX with standard 14-period baseline.
- Long trend filter: fast EMA > slow EMA.
- Long entry: +DI crosses above ADX while ADX is below threshold 30.
- One open position maximum.

### Exit
- Exit long when +DI crosses below ADX while ADX is above threshold 30.
- Protective stop remains active until signal exit.

### Stop Loss
- Source default stop loss = 8% adverse move from entry.
- DWX baseline stop = min(8% price stop, 2.5 * ATR(14)) to keep CFD risk bounded.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Long-only baseline because source describes only +DI long logic.
- Spread must be <= 15% of protective stop distance.
- DWX port targets EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, and GER40.DWX.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - EMA trend filter gates long entries.
- [[concepts/momentum]] - +DI/ADX cross captures strengthening positive directional movement.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `eemani123` are cited. |
| R2 Mechanical | PASS | Source gives explicit EMA filter, +DI/ADX entry, +DI/ADX exit, threshold, and stop loss. |
| R3 Data Available | PASS | Uses OHLC-derived EMA and DMI/ADX indicators available on DWX FX, gold, oil, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicators and thresholds, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10171_tv-vwap-rsi-dip]] - same TradingView author, different VWAP/RSI mean-reversion mechanic.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
