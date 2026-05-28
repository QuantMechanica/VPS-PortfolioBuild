---
ea_id: QM5_10217
slug: tv-price-vol-brk
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [XAUUSD.DWX, NDX.DWX, GER40.DWX, EURUSD.DWX, GBPJPY.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/breakout]]"
  - "[[concepts/volume-confirmation]]"
indicators:
  - "[[indicators/moving-average]]"
  - "[[indicators/volume-breakout]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 35
last_updated: 2026-05-19
g0_approval_reasoning: "R1 URL+author cited; R2 price+volume breakout entries with protective bracket exits and ~35 trades/year/symbol; R3 testable on DWX gold/index/FX via tick volume; R4 fixed non-ML one-position rules."
---

# TradingView Price Volume Breakout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `Price and Volume Breakout Buy Strategy [TradeDots]`, author handle `tradedots`, updated 2024-05-17, https://www.tradingview.com/script/jc2hs2qK-Price-and-Volume-Breakout-Buy-Strategy-TradeDots/

## Mechanik

Target symbols: XAUUSD.DWX, NDX.DWX, GER40.DWX, EURUSD.DWX, GBPJPY.DWX.

### Entry
Use H1 baseline. Define an examination window of N candles for price and volume. Long when close exceeds the maximum close/high benchmark from that window, current volume exceeds the maximum volume benchmark from the same window, and price is above the designated trend moving average. Short mode was added in the source release notes: short when close breaks below the corresponding price benchmark, volume breaks above the volume benchmark, and price is below the trend moving average.

### Exit
Source page does not specify a full exit rule beyond the strategy shell. Use V5 protective bracket for G0 draft: take profit at 2.0R and stop at 1.0R, where R is max(previous-bar range, 1.5 * ATR(14)). Close opposite position before any new opposite signal.

### Stop Loss
V5 protective default: long stop below the breakout bar low or 1.5 * ATR(14), whichever is wider up to a 3.0 * ATR cap; mirror for shorts.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number. Ignore source percent-equity demo sizing.

### Zusatzliche Filter
Use tick volume on DWX CFDs as the volume proxy. Require breakout candle close confirmation; no intrabar entries. Favor XAUUSD and index CFDs first because the source targets high-volatility assets.

## Concepts (was ist das fur eine Strategie)
- [[concepts/breakout]] - simultaneous price and volume range expansion.
- [[concepts/volume-confirmation]] - volume must exceed the recent benchmark with price.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `tradedots` are cited. |
| R2 Mechanical | PASS | Source gives deterministic price window, volume window, MA filter, and direction options; exit gap is filled with V5 protective defaults. |
| R3 Data Available | PASS | OHLC, moving average, and tick-volume proxies are available on DWX gold, index, and FX CFDs. |
| R4 ML Forbidden | PASS | Fixed breakout and volume conditions; no ML, grid, martingale, DCA, or performance-adaptive sizing. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView popular Pine strategy page.

## Verwandte Strategien
- [[strategies/QM5_10199_tv-vsa-absorb-fx]] - volume-confirmed price action.
- [[strategies/QM5_10189_tv-piv-vwap-brk]] - pivot breakout with volume/momentum filters.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
