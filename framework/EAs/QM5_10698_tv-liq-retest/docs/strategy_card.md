---
ea_id: QM5_10698
slug: tv-liq-retest
type: strategy
source_id: d11962d5-19ca-5b8b-b5fc-e3bd0a620ed7
source_citation: "Apicode, Liquidity Retest Strategy (Apicode) - TP/SL Lines Fixed, TradingView open-source strategy, 2025-12-27, https://www.tradingview.com/script/GjkwcL4B/"
sources:
  - "[[sources/tradingview-mechanical-strategy-scripts]]"
concepts:
  - "[[concepts/liquidity-sweep]]"
  - "[[concepts/support-resistance]]"
  - "[[concepts/mean-reversion]]"
indicators:
  - "[[indicators/atr]]"
  - "[[indicators/vwap]]"
  - "[[indicators/ema]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 140
last_updated: 2026-05-22
g0_approval_reasoning: "R1 PASS TradingView URL/author cited; R2 PASS mechanical pivot liquidity retest entries + ATR/percent exits with ~140 trades/year/symbol; R3 PASS OHLC/ATR/EMA testable on DWX with optional volume caveat; R4 PASS fixed non-ML no-pyramiding rules."
---

# TradingView Liquidity Retest Rejection

## Quelle
- Source: [[sources/tradingview-mechanical-strategy-scripts]]
- Page / Timestamp: TradingView script `Liquidity Retest Strategy (Apicode) - TP/SL Lines Fixed`, author handle `Apicode`, open-source strategy, published 2025-12-27, https://www.tradingview.com/script/GjkwcL4B/

## Mechanik

### Entry
Use M5-M30 baseline on liquid DWX symbols.

- Detect pivot highs and lows using configurable left/right bars.
- Store resistance levels from confirmed pivot highs and support levels from confirmed pivot lows, capped by max levels.
- Each bar, select the nearest support below price and resistance above price within `ATR * maxDistATR`.
- Long setup:
  - Low touches or crosses selected support.
  - Close reclaims above the support.
  - Candle is bullish.
  - Wick below support is at least `ATR * minWickATR`.
  - Optional filters, if enabled, pass: volume > SMA(volume,20)*multiplier, close above VWAP-like series, EMA fast > EMA slow.
  - Enter long if no long position is open.
- Short setup:
  - High touches or crosses selected resistance.
  - Close rejects back below the resistance.
  - Candle is bearish.
  - Wick above resistance is at least `ATR * minWickATR`.
  - Optional filters pass symmetrically.
  - Enter short if no short position is open.

### Exit
- Static TP/SL in ATR mode or percent mode; P2 baseline uses ATR mode.
- Optional trailing stop is disabled in P2 baseline, then tested in P3.
- Exit on TP, SL, or end-of-session flat if session window is added.

### Stop Loss
- P2 baseline long stop = entry - ATR_at_entry * slATR.
- P2 baseline short stop = entry + ATR_at_entry * slATR.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per symbol/magic.

### Zusatzliche Filter
- No pyramiding; source explicitly gates entries by current position size.
- Backtest lookback-days filter disabled for full P2 history.
- VWAP-like and volume filters are optional; P2 tests both disabled and enabled variants.

## Concepts (was ist das fur eine Strategie)
- [[concepts/liquidity-sweep]] - wick through a pivot S/R level followed by reclaim/rejection.
- [[concepts/support-resistance]] - pivot levels define the working sweep levels.
- [[concepts/mean-reversion]] - entry fades failed level breaks.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `Apicode` are cited. |
| R2 Mechanical | PASS | Source documents pivot level construction, ATR proximity, candle rejection rules, position gating, and TP/SL logic. |
| R3 Data Available | PASS/UNKNOWN | OHLC, ATR, EMA, and sessions are available; volume/VWAP-like filters may need DWX tick-volume approximation. |
| R4 ML Forbidden | PASS | Fixed indicator/rule system with pyramiding 0; no ML, grid, or martingale. |

## R3
Primary P2 basket: EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD, GER40.DWX, NDX.DWX. Volume-filter variants are UNKNOWN until tested with DWX tick volume.

## Author Claims
- Source says the strategy targets liquidity sweeps around meaningful support/resistance levels followed by retest and rejection.
- Source says support rejection requires low <= support, close > support, bullish candle, and sufficient wick below the level.
- Source says no pyramiding is allowed.

## Parameters To Test
- Pivot lookback/right bars: 3/3, 5/5, 8/5.
- Max distance to level: 0.5, 1.0, 1.5 ATR.
- Minimum wick: 0.1, 0.25, 0.5 ATR.
- Exit mode: ATR SL/TP vs percent SL/TP.
- Optional filters: none, EMA only, EMA+VWAP, EMA+VWAP+volume.

## Initial Risk Profile
Level-retest reversal system with moderate cadence. Main risks are stale pivot levels, over-filtering from tick-volume approximations, and poor fills when sweep candles are large.

## Pipeline-Verlauf
- G0: 2026-05-22, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- QM5_10655 tv-liq-sweeper
- QM5_10680 tv-liq-engulf

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
