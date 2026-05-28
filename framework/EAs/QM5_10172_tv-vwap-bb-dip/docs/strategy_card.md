---
ea_id: QM5_10172
slug: tv-vwap-bb-dip
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/bollinger-bands]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 mechanical EMA/VWAP/Bollinger entry and upper-band/stop exit with ~70 trades/year/symbol; R3 DWX index/FX/gold port testable with SP500.DWX T6 caveat; R4 no ML/grid/martingale or pyramiding."
---

# TradingView VWAP Bollinger Dip

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `VWAP and BB strategy [EEMANI]`, author handle `eemani123`, published 2020-09-20 and updated 2020-09-21, https://www.tradingview.com/script/oZYSB6Ui-VWAP-and-BB-strategy-EEMANI/

## Mechanik

### Entry
Use H1 bars as first baseline; port equity-index usage to SP500.DWX and NDX.DWX.

- Long-only baseline.
- Trend filter: EMA(13) > EMA(55). Source originally listed EMA50/EMA200, then release notes changed fast/slow values to 13/55; baseline follows the latest visible page.
- VWAP filter: current close > session VWAP.
- Dip condition: price touched or closed below the lower Bollinger Band within the last 10 completed candles.
- Enter long when the dip condition exists and current close is above session VWAP while the EMA trend filter remains bullish.

### Exit
- Exit long when price closes above the upper Bollinger Band.
- Emergency exit on protective stop.

### Stop Loss
- Source default stop loss is 5%.
- Baseline stop: tighter of 5% from entry or 2.5 ATR(14).

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Session VWAP resets once per trading day.
- Bollinger baseline: SMA(20), 2.0 standard deviations unless P1 source-code verification shows different defaults.
- Standard V5 spread/news filters.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - lower-band dip after bullish VWAP recovery
- [[concepts/trend-filter]] - EMA stack plus session VWAP prevent countertrend entries

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `eemani123` are cited. |
| R2 Mechanical | PASS | Source gives explicit EMA trend, VWAP, Bollinger dip, Bollinger exit, and stop rules. |
| R3 Data Available | PASS | OHLC/VWAP/Bollinger/EMA mechanics port to DWX index CFDs, FX, and gold. SP500.DWX live-promotion caveat applies if SP500.DWX is the only passing index analog. |
| R4 ML Forbidden | PASS | No ML, grid, martingale, pyramiding, or performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_9984_tv-bb-outside-candle-scalping]] - related Bollinger mechanic, but this card uses VWAP-trend dip recovery rather than outside-candle scalping.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
