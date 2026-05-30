---
ea_id: QM5_10200
slug: tv-bhd-trend-tp
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/pullback]]"
indicators:
  - "[[indicators/ema]]"
  - "[[indicators/rsi]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 70
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical EMA/RSI pullback entry with ATR TP/SL and ~70 trades/year/symbol; R3 portable to DWX FX/gold/indices; R4 fixed rules no ML/grid/martingale one-position compatible."
---

# TradingView BHD Trend Pullback TP

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Take Profit On Trend (by BHD_Trade_Bot)`, author handle `BHD_Trade_Bot`, published 2021-09-28, https://www.tradingview.com/script/iqtkNFT2-Take-Profit-On-Trend-by-BHD-Trade-Bot/

## Mechanik

### Entry
Use H1 bars in baseline.

- Long-only entry while flat:
  - Long-term trend condition: EMA(200) is rising and RSI(200) > 51.
  - Short-term pullback condition: the last two completed candles are bearish.
  - Enter long at the next bar open after both conditions are true.
- No short side in the source version.

### Exit
- Source exit is fixed-unit take profit / stop loss.
- Baseline port replaces the source's crypto-specific BHD unit with ATR distance:
  - TP = entry + 1.0 * ATR(14).
  - SL = entry - 2.0 * ATR(14).
- Close on whichever bracket side is hit first.

### Stop Loss
2.0 * ATR(14) below entry. Skip trades where spread exceeds 15% of stop distance.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, NDX.DWX, GER40.DWX.
- Source was optimized for crypto H1. DWX port uses the same trend-pullback logic on liquid FX, gold, and index CFDs.
- Disable any source dollar/order-size assumptions.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - long-term EMA/RSI regime.
- [[concepts/pullback]] - enters after two bearish candles inside an uptrend.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `BHD_Trade_Bot` are cited. |
| R2 Mechanical | PASS | Source gives trend condition, pullback entry, and TP/SL exit. |
| R3 Data Available | PASS | EMA, RSI, candle direction, and ATR bracket are available on DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, no ML, no grid, no martingale, and one-position-per-magic compatible. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10180_tv-fut-ema-rsi-pull]] - related EMA/RSI pullback family with a richer futures rule set.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
