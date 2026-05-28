---
ea_id: QM5_10215
slug: tv-cci-ema-fx
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, USDCAD.DWX, GBPJPY.DWX, GBPUSD.DWX, XAUUSD.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/mean-reversion]]"
  - "[[concepts/trend-filter]]"
indicators:
  - "[[indicators/commodity-channel-index]]"
  - "[[indicators/moving-average]]"
  - "[[indicators/exponential-moving-average]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 55
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 CCI/MA/EMA entries with fixed TP/SL and ~55 trades/year/symbol; R3 testable on DWX FX/gold; R4 fixed non-ML one-position rules."
---

# TradingView CCI EMA Forex Reversal

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Commodity Channel Index CCI + EMA strategy`, author handle `Burdiga84`, published 2025-12-28, https://www.tradingview.com/script/R1oQ3nrw/

## Mechanik

Target symbols: EURUSD.DWX, USDCAD.DWX, GBPJPY.DWX, GBPUSD.DWX, XAUUSD.DWX.

### Entry
Use H1 baseline. Compute CCI(20) on HLC3, a smoothing MA of CCI with SMA(14), EMA50, and EMA200. Long when CCI crosses above the smoothing MA while CCI is between -100 and 0, and EMA50 > EMA200 if the trend filter is enabled. Short when CCI crosses below the smoothing MA while CCI is between 0 and +100, and EMA50 < EMA200 if the trend filter is enabled.

### Exit
Exit at fixed take-profit or fixed stop-loss. If an opposite valid signal appears while a position is open, close the current position first and open the opposite side only if the one-position rule is clear.

### Stop Loss
Source default stop is 0.5% from entry. For FX P2, also test ATR-normalized equivalent if percentage distance is too tight for the symbol spread.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
Source explicitly recommends major FX pairs and lists USDCAD, EURUSD, and GBPJPY as top-performing examples. Use those first, with GBPUSD and XAUUSD as liquidity/volatility cross-checks.

## Concepts (was ist das fur eine Strategie)
- [[concepts/mean-reversion]] - CCI pulls back into bounded oversold/overbought zones before crossing its smoothing line.
- [[concepts/trend-filter]] - EMA50/EMA200 alignment gates direction.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Burdiga84` are cited. |
| R2 Mechanical | PASS | Source gives explicit CCI crossover, zone, EMA filter, TP, and SL rules. |
| R3 Data Available | PASS | CCI, MA, EMA, OHLC, and fixed percentage or ATR-equivalent stops are available on DWX FX and gold CFDs. |
| R4 ML Forbidden | PASS | Fixed indicator rules, fixed TP/SL, one position at a time; no ML, grid, martingale, or online adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10212_tv-hilo-period-break]] - same source family batch, but breakout rather than oscillator reversal.
- [[strategies/QM5_10188_tv-adx-di-ema-long]] - indicator-filtered FX trend family.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
