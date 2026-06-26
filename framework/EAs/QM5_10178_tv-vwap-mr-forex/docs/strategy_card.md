---
ea_id: QM5_10178
slug: tv-vwap-mr-forex
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/range-trading]]"
indicators:
  - "[[indicators/vwap]]"
  - "[[indicators/rsi]]"
  - "[[indicators/volume-filter]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 180
last_updated: 2026-05-19
g0_approval_reasoning: "R1 exact TradingView URL cited; R2 mechanical VWAP/RSI/volume entries with VWAP/stop/time exits and ~180 trades/year/symbol; R3 forex DWX testable; R4 no ML/grid/martingale, one position per magic."
---

# TradingView VWAP Mean Reversion Forex

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `VWAP Mean Reversion Strategy Range Bound Forex RSI Volume`, author handle `Forex_Trading_Karnataka`, published 2026-03-29, https://www.tradingview.com/script/9SEB7IHb-VWAP-Mean-Reversion-Strategy-Range-Bound-Forex-RSI-Volume/

## Mechanik

### Entry
Use M15 or M30 bars, long and short.

- Compute rolling VWAP over 20 bars using typical price weighted by tick volume.
- Compute a volume-weighted absolute-deviation band around rolling VWAP; baseline uses 2.0 deviation bands.
- Compute RSI(14) on close.
- Compute volume spike filter: current tick volume must be <= 2.0 * SMA(volume, 20).
- Long entry: close crosses below lower VWAP deviation band, RSI(14) <= 30, and no volume spike.
- Short entry: close crosses above upper VWAP deviation band, RSI(14) >= 70, and no volume spike.
- Allow entries only when ADX(14) <= 25 to keep the source's range-bound premise mechanical.

### Exit
- Long take profit: close position when bid/close returns to rolling VWAP.
- Short take profit: close position when ask/close returns to rolling VWAP.
- Protective stop: fixed 0.75% adverse move from entry or 1.5 ATR(14), whichever is tighter.
- Time stop: close after 24 bars if neither VWAP target nor stop was reached.

### Stop Loss
- Source specifies fixed percentage risk; baseline freezes this as 0.75% and caps it at 1.5 ATR(14).
- Do not widen stop after entry.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Primary DWX symbols: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, EURGBP.DWX.
- Skip high-impact news windows around the traded currency pair.
- Spread must be <= 15% of stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - deviation from rolling fair value back to VWAP.
- [[concepts/range-trading]] - source explicitly targets sideways forex phases.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Forex_Trading_Karnataka` are cited. |
| R2 Mechanical | PASS | Source gives directional entries from VWAP bands, RSI confirmation, volume-spike filter, VWAP target, and fixed-risk stop. |
| R3 Data Available | PASS | Source targets forex directly; all inputs use OHLC and tick-volume data available on DWX FX symbols. |
| R4 ML Forbidden | PASS | No ML, neural net, grid, martingale, pyramiding, or live performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10171_tv-vwap-rsi-dip]] - related VWAP/RSI mean-reversion family with a different trend-regime filter.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
