---
ea_id: QM5_10202
slug: tv-dema-atr-scaleout
type: strategy
source_id: 30591366-874b-5bee-b47c-da2fca20b728
target_symbols: [EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX]
sources:
  - "[[sources/tradingview-popular-pine-scripts]]"
concepts:
  - "[[concepts/trend-following]]"
  - "[[concepts/volatility-breakout]]"
indicators:
  - "[[indicators/dema]]"
  - "[[indicators/atr]]"
g0_status: APPROVED
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: G0
expected_trades_per_year_per_symbol: 80
last_updated: 2026-05-19
g0_approval_reasoning: "R1 TradingView URL/author cited; R2 mechanical DEMA trend-state entries with ATR target/stop and ~80 trades/year/symbol; R3 portable to DWX FX/gold/indices; R4 fixed indicator rules no ML/grid/martingale one-position compatible."
---

# TradingView DEMA ATR Scaleout

## Quelle
- Source: [[sources/tradingview-popular-pine-scripts]]
- Page / Timestamp: TradingView script `DEMA ATR Strategy [PrimeAutomation]`, author handle `ChartPrime`, published 2025-11-25 and updated 2026-03-19, https://www.tradingview.com/script/rqRd3f62-DEMA-ATR-Strategy-PrimeAutomation/

## Mechanik

### Entry
Use H1 bars in baseline.

- Compute DEMA baseline and ATR volatility envelope.
- Adjusted DEMA trend state:
  - Bullish when adjusted DEMA rises above its prior value.
  - Bearish when adjusted DEMA falls below its prior value.
- Long entry while flat or short: bullish state shift.
- Short entry while flat or long: bearish state shift.
- One position maximum; opposite signal closes current position and opens the reverse side on the next bar.

### Exit
- Source uses three ATR profit targets: 1x, 2x, 3x ATR with 30% / 30% / 40% scale-out.
- V5 baseline uses one full-position target at 2.0 * ATR(14) to preserve one-position accounting.
- Opposite adjusted-DEMA trend shift exits at market if target has not been reached.

### Stop Loss
Initial stop = 1.5 * ATR(14) from entry, opposite trade direction. P3 may test 1.0-2.5 ATR.

### Position Sizing
V5 default: fixed-risk $1,000 for P2 baseline, one position per magic number.

### Zusatzliche Filter
- Target symbols: EURUSD.DWX, GBPUSD.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX.
- Trade only after ATR(14) and DEMA warmup are complete.
- Spread must be <= 15% of stop distance.

## Concepts (was ist das fur eine Strategie)
- [[concepts/trend-following]] - DEMA direction shift.
- [[concepts/volatility-breakout]] - ATR envelope and ATR-scaled exits.

## R1-R4 Bewertung
| Kriterium | Status | Begrundung |
|-----------|--------|------------|
| R1 Track Record | PASS | Exact TradingView URL and author handle `ChartPrime` are cited. |
| R2 Mechanical | PASS | Source defines adjusted-DEMA directional shifts, ATR targets, and opposite-signal exits. |
| R3 Data Available | PASS | DEMA, ATR, and OHLC logic is portable to DWX FX, gold, and index CFDs. |
| R4 ML Forbidden | PASS | Volatility-adjusted indicator rules only; no ML, grid, martingale, pyramiding, or performance-adaptive parameters. |

## Pipeline-Verlauf
- G0: 2026-05-19, PENDING, drafted from TradingView script page.

## Verwandte Strategien
- [[strategies/QM5_10175_tv-atr-ema-vwap]] - related ATR trend family, but this card uses adjusted DEMA trend shifts.

## Lessons Learned (wahrend Pipeline-Lauf)
- TBD
